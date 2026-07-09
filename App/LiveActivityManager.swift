import ActivityKit
import CoreLocation
import Foundation
import Observation
import os

private let log = Logger(subsystem: "com.pupweather.app", category: "LiveActivity")

@MainActor
@Observable
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    /// 1 primary + 3 added, keeps background refresh fast and the Lock
    /// Screen stack scannable.
    static let maxTrackedLocations = 4

    /// How often the dog wanders to a new spot while the app is frontmost.
    /// Background moves ride along with BGAppRefresh weather updates.
    private static let wanderInterval: Duration = .seconds(120)

    private static let badgeScaleKey = "com.pupweather.badgeScale"

    /// Global user-chosen weather-badge scale, edited from the home-view
    /// preview. Rides along in every ContentState, so the widget never needs
    /// shared storage. Persisted app-side across launches.
    private(set) var badgeScale: Double = 1.0

    private(set) var trackedLocations: [TrackedLocation] = []
    private(set) var weatherByLocation: [String: CurrentWeather] = [:]
    private(set) var placeNameByLocation: [String: String] = [:]
    private(set) var lastRefreshByLocation: [String: Date] = [:]
    private(set) var errorByLocation: [String: String] = [:]
    private(set) var layoutByLocation: [String: SceneLayout] = [:]
    private(set) var refreshingIDs: Set<String> = []
    /// Location IDs with a live `Activity` right now. Mirrors ActivityKit's
    /// own state into an `@Observable` property so SwiftUI re-renders when an
    /// activity starts/ends (including externally, e.g. the user dismissing
    /// it from the Lock Screen), since `Activity<...>.activities` itself
    /// isn't observable.
    private(set) var runningLocationIDs: Set<String> = []
    private(set) var errorMessage: String?
    private(set) var statusMessage: String?

    private var wanderTasks: [String: Task<Void, Never>] = [:]
    private var ensuringIDs: Set<String> = []

    private init() {
        trackedLocations = TrackedLocationStore.load()
        // `object(forKey:)`, not `double(forKey:)` — the latter returns 0
        // when the key is missing, which would clamp up to minScale but
        // still lose the "never customized" default.
        badgeScale = UserDefaults.standard.object(forKey: Self.badgeScaleKey) as? Double ?? 1.0
        if trackedLocations.isEmpty {
            trackedLocations = [TrackedLocation(selection: .gps, isPrimary: true)]
        }
        syncActivityState()
        Task {
            for await _ in Activity<PupActivityAttributes>.activityUpdates {
                syncActivityState()
            }
        }
    }

    private func activity(for locationID: String) -> Activity<PupActivityAttributes>? {
        Activity<PupActivityAttributes>.activities.first { $0.attributes.locationID == locationID }
    }

    var primaryLocation: TrackedLocation? {
        trackedLocations.first { $0.isPrimary }
    }

    var scene: PupScene {
        guard let id = primaryLocation?.id else { return .clearDay }
        return weatherByLocation[id]?.scene ?? .clearDay
    }

    var activitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var activityCount: Int {
        runningLocationIDs.count
    }

    var isActivityRunning: Bool {
        !runningLocationIDs.isEmpty
    }

    func isActivityRunning(for id: String) -> Bool {
        runningLocationIDs.contains(id)
    }

    private func isLocationDenied(_ selection: LocationSelection) -> Bool {
        guard case .gps = selection else { return false }
        switch LocationService.shared.authorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    private func displayName(for location: TrackedLocation) -> String {
        switch location.selection {
        case .gps: return "Current Location"
        case .manual(let city): return city.displayName
        }
    }

    // MARK: - Tracked locations

    @discardableResult
    func addLocation(_ selection: LocationSelection) async -> Bool {
        let id = selection.stableID
        guard !trackedLocations.contains(where: { $0.id == id }) else {
            statusMessage = "That location is already being tracked."
            return false
        }
        guard trackedLocations.count < Self.maxTrackedLocations else {
            statusMessage = "You can track up to \(Self.maxTrackedLocations) locations at once."
            return false
        }
        let location = TrackedLocation(selection: selection, isPrimary: false)
        trackedLocations.append(location)
        TrackedLocationStore.save(trackedLocations)
        await ensureActivityRunning(for: location)
        return true
    }

    func removeLocation(id: String) async {
        guard let location = trackedLocations.first(where: { $0.id == id }), !location.isPrimary else { return }
        wanderTasks[id]?.cancel()
        wanderTasks[id] = nil
        if let activity = activity(for: id) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        trackedLocations.removeAll { $0.id == id }
        clearState(for: id)
        TrackedLocationStore.save(trackedLocations)
        syncActivityState()
    }

    func setPrimaryLocation(_ selection: LocationSelection) async {
        guard var primary = primaryLocation, primary.selection != selection else { return }
        let oldID = primary.id
        wanderTasks[oldID]?.cancel()
        wanderTasks[oldID] = nil
        if let oldActivity = activity(for: oldID) {
            await oldActivity.end(nil, dismissalPolicy: .immediate)
        }
        clearState(for: oldID)

        primary.selection = selection
        primary.addedAt = .now
        if let index = trackedLocations.firstIndex(where: { $0.isPrimary }) {
            trackedLocations[index] = primary
        }
        TrackedLocationStore.save(trackedLocations)
        await ensureActivityRunning(for: primary)
    }

    private func clearState(for id: String) {
        weatherByLocation[id] = nil
        placeNameByLocation[id] = nil
        lastRefreshByLocation[id] = nil
        errorByLocation[id] = nil
        layoutByLocation[id] = nil
    }

    // MARK: - Lifecycle

    func ensureActivityRunning() async {
        for location in trackedLocations {
            await ensureActivityRunning(for: location)
        }
    }

    func ensureActivityRunning(for location: TrackedLocation) async {
        let id = location.id
        guard !ensuringIDs.contains(id) else { return }
        ensuringIDs.insert(id)
        defer { ensuringIDs.remove(id) }

        guard activitiesEnabled else {
            log.error("Live Activities are not enabled for this app")
            errorMessage = "Live Activities are disabled. Turn them on in Settings → PupWeather → Live Activities."
            statusMessage = nil
            return
        }

        if activity(for: id) != nil {
            let refreshed = await refresh(for: id)
            if refreshed, let weather = weatherByLocation[id] {
                await pushUpdate(weather, for: id)
            }
            statusMessage = "Lock Screen pup is active."
            startWanderLoop(for: id)
            return
        }

        let refreshed = await refresh(for: id)
        if !refreshed && isLocationDenied(location.selection) {
            statusMessage = nil
            return
        }

        await requestActivity(for: location)
    }

    private func requestActivity(for location: TrackedLocation) async {
        let id = location.id
        let weather = weatherByLocation[id]
        let attributes = PupActivityAttributes(
            startedAt: .now,
            locationID: id,
            locationName: displayName(for: location)
        )
        layoutByLocation[id] = SceneLayout.makeInitial(for: weather?.scene ?? .clearDay)
        let state = contentState(
            scene: weather?.scene ?? .clearDay,
            temperatureC: weather?.temperatureC ?? 20,
            id: id
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: Date(timeIntervalSinceNow: 3 * 3600))
            )
            log.info("Live Activity started: \(activity.id), location=\(id)")
            errorByLocation[id] = nil
            statusMessage = weather == nil
                ? "Lock Screen pup restored with a default scene."
                : "Lock Screen pup is active."
            startWanderLoop(for: id)
            syncActivityState()
            BackgroundRefresher.schedule()
        } catch {
            log.error("Activity.request failed: \(error)")
            errorByLocation[id] = "Could not start the Lock Screen pup: \(error.localizedDescription)"
            statusMessage = nil
            syncActivityState()
        }
    }

    func stopActivity() async {
        for task in wanderTasks.values {
            task.cancel()
        }
        wanderTasks.removeAll()
        for activity in Activity<PupActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        weatherByLocation.removeAll()
        placeNameByLocation.removeAll()
        lastRefreshByLocation.removeAll()
        errorByLocation.removeAll()
        layoutByLocation.removeAll()
        syncActivityState()
        statusMessage = "Live Activity stopped."
    }

    // MARK: - Dog wandering

    /// While the app is frontmost, send each location's dog somewhere new
    /// every couple of minutes. Independent per-location tasks so cards
    /// animate on their own jittered cadence instead of in lockstep.
    private func startWanderLoop(for id: String) {
        guard wanderTasks[id] == nil else { return }
        wanderTasks[id] = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.wanderInterval)
                guard let self, !Task.isCancelled else { return }
                await self.wander(for: id)
            }
        }
    }

    private func wander(for id: String) async {
        guard let activity = activity(for: id) else { return }
        let scene = weatherByLocation[id]?.scene ?? .clearDay
        let layout = SceneLayout.wander(from: layoutByLocation[id] ?? .makeInitial(for: scene), scene: scene)
        layoutByLocation[id] = layout
        let state = contentState(scene: scene, temperatureC: weatherByLocation[id]?.temperatureC ?? 20, id: id)
        await activity.update(
            .init(state: state, staleDate: Date(timeIntervalSinceNow: 3 * 3600))
        )
    }

    // MARK: - Refresh (called on launch/foreground and from background task)

    @discardableResult
    func refresh(for id: String) async -> Bool {
        guard let location = trackedLocations.first(where: { $0.id == id }) else { return false }
        guard !refreshingIDs.contains(id) else { return false }
        refreshingIDs.insert(id)
        defer { refreshingIDs.remove(id) }
        do {
            let coordinate: CLLocationCoordinate2D
            var gpsLocation: CLLocation?
            switch location.selection {
            case .gps:
                let loc = try await LocationService.shared.currentLocation()
                coordinate = loc.coordinate
                gpsLocation = loc
                placeNameByLocation[id] = nil
            case .manual(let city):
                coordinate = city.coordinate
                placeNameByLocation[id] = city.displayName
            }
            let weather = try await WeatherService.fetch(for: coordinate)
            weatherByLocation[id] = weather
            lastRefreshByLocation[id] = .now
            errorByLocation[id] = nil
            if let gpsLocation {
                await reverseGeocode(gpsLocation, for: id)
            }
            await pushUpdate(weather, for: id)
            return true
        } catch LocationService.LocationError.denied {
            errorByLocation[id] = "Location access is denied. Enable it in Settings to get local weather, or pick a city manually."
            return false
        } catch {
            errorByLocation[id] = "Weather refresh failed: \(error.localizedDescription)"
            return false
        }
    }

    /// Fans out refreshes for every tracked location concurrently so N
    /// network round trips (plus any reverse geocodes) fit inside the
    /// ~20s BGAppRefreshTask execution window.
    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            for location in trackedLocations {
                group.addTask { await self.refresh(for: location.id) }
            }
        }
    }

    private func pushUpdate(_ weather: CurrentWeather, for id: String) async {
        guard let activity = activity(for: id) else { return }
        // Every update doubles as a wander tick so the dog also moves on
        // background refreshes, not just on the foreground timer.
        let layout = SceneLayout.wander(from: layoutByLocation[id] ?? .makeInitial(for: weather.scene), scene: weather.scene)
        layoutByLocation[id] = layout
        let state = contentState(scene: weather.scene, temperatureC: weather.temperatureC, id: id)
        await activity.update(
            .init(state: state, staleDate: Date(timeIntervalSinceNow: 3 * 3600))
        )
    }

    private func contentState(
        scene: PupScene,
        temperatureC: Double,
        id: String
    ) -> PupActivityAttributes.ContentState {
        .init(
            scene: scene,
            temperatureC: temperatureC,
            updatedAt: .now,
            layout: layoutByLocation[id] ?? .makeInitial(for: scene),
            badgeScale: badgeScale
        )
    }

    // MARK: - Badge size

    /// Persists a new badge scale and pushes it to every running activity.
    /// Called once per resize (on drag end), so it costs one ActivityKit
    /// update per activity. Each activity keeps its current layout — the
    /// scene view slides the dog out of the enlarged keep-out zone instead
    /// of teleporting it.
    func setBadgeScale(_ scale: Double) async {
        let clamped = WeatherBadgeMetrics.clampedToHardRange(scale)
        guard clamped != badgeScale else { return }
        badgeScale = clamped
        UserDefaults.standard.set(clamped, forKey: Self.badgeScaleKey)
        for activity in Activity<PupActivityAttributes>.activities {
            let id = activity.attributes.locationID
            let weather = weatherByLocation[id]
            let state = contentState(
                scene: weather?.scene ?? .clearDay,
                temperatureC: weather?.temperatureC ?? 20,
                id: id
            )
            await activity.update(
                .init(state: state, staleDate: Date(timeIntervalSinceNow: 3 * 3600))
            )
        }
    }

    private func reverseGeocode(_ location: CLLocation, for id: String) async {
        let geocoder = CLGeocoder()
        if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
            placeNameByLocation[id] = placemark.locality ?? placemark.subAdministrativeArea
        } else {
            placeNameByLocation[id] = nil
        }
    }

    /// Refreshes `runningLocationIDs` from ActivityKit's live state. For the
    /// primary location, a missing activity is auto-restarted (matches the
    /// app's existing zero-config behavior on foreground). Secondary
    /// locations are left as "not running" instead — silently resurrecting
    /// something the user dismissed from the Lock Screen would be
    /// surprising; their card shows a manual "Resume" affordance instead.
    private func syncActivityState() {
        let ids = Set(Activity<PupActivityAttributes>.activities.map(\.attributes.locationID))
        runningLocationIDs = ids
        if let primary = primaryLocation, !ids.contains(primary.id) {
            Task { await self.ensureActivityRunning(for: primary) }
        }
    }
}
