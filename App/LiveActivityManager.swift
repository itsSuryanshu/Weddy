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

    /// How often the dog wanders to a new spot while the app is frontmost.
    /// Background moves ride along with BGAppRefresh weather updates.
    private static let wanderInterval: Duration = .seconds(120)

    private(set) var currentWeather: CurrentWeather?
    private(set) var placeName: String?
    private(set) var lastRefresh: Date?
    private(set) var errorMessage: String?
    private(set) var statusMessage: String?
    private(set) var isRefreshing = false
    private(set) var isActivityRunning = false
    private(set) var layout = SceneLayout.makeInitial(for: .clearDay)
    private var isEnsuringActivity = false
    private var wanderTask: Task<Void, Never>?

    private init() {
        syncActivityState()
        Task {
            for await _ in Activity<PupActivityAttributes>.activityUpdates {
                syncActivityState()
            }
        }
    }

    private var activity: Activity<PupActivityAttributes>? {
        Activity<PupActivityAttributes>.activities.first
    }

    var scene: PupScene {
        currentWeather?.scene ?? .clearDay
    }

    var activitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var activityCount: Int {
        Activity<PupActivityAttributes>.activities.count
    }

    private var isLocationDenied: Bool {
        switch LocationService.shared.authorizationStatus {
        case .denied, .restricted:
            true
        default:
            false
        }
    }

    // MARK: - Lifecycle

    func ensureActivityRunning() async {
        guard !isEnsuringActivity else { return }
        isEnsuringActivity = true
        defer { isEnsuringActivity = false }

        guard activitiesEnabled else {
            log.error("Live Activities are not enabled for this app")
            errorMessage = "Live Activities are disabled. Turn them on in Settings → PupWeather → Live Activities."
            statusMessage = nil
            return
        }

        let refreshed = await refresh()

        if activity != nil {
            isActivityRunning = true
            if let weather = currentWeather {
                await pushUpdate(weather)
            }
            statusMessage = "Lock Screen pup is active."
            startWanderLoop()
            return
        }

        if !refreshed && isLocationDenied {
            statusMessage = nil
            return
        }

        await requestActivity()
    }

    private func requestActivity() async {
        let weather = currentWeather
        let attributes = PupActivityAttributes(startedAt: .now)
        layout = SceneLayout.makeInitial(for: weather?.scene ?? .clearDay)
        let state = contentState(
            scene: weather?.scene ?? .clearDay,
            temperatureC: weather?.temperatureC ?? 20
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: Date(timeIntervalSinceNow: 3 * 3600))
            )
            log.info("Live Activity started: \(activity.id), scene=\(state.scene.rawValue)")
            errorMessage = nil
            statusMessage = weather == nil
                ? "Lock Screen pup restored with a default scene."
                : "Lock Screen pup is active."
            isActivityRunning = true
            startWanderLoop()
            BackgroundRefresher.schedule()
        } catch {
            log.error("Activity.request failed: \(error)")
            errorMessage = "Could not restore the Lock Screen pup: \(error.localizedDescription)"
            statusMessage = nil
            syncActivityState()
        }
    }

    func stopActivity() async {
        wanderTask?.cancel()
        wanderTask = nil
        for activity in Activity<PupActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        syncActivityState()
        statusMessage = "Live Activity stopped."
    }

    // MARK: - Dog wandering

    /// While the app is frontmost, send the dog somewhere new every couple of
    /// minutes. Each push animates the dog to a fresh spot / pose; on warm
    /// sunny scenes that's mostly jumping around with the butterflies.
    private func startWanderLoop() {
        guard wanderTask == nil else { return }
        wanderTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.wanderInterval)
                guard let self, !Task.isCancelled else { return }
                await self.wander()
            }
        }
    }

    private func wander() async {
        guard let activity else { return }
        let scene = currentWeather?.scene ?? .clearDay
        layout = SceneLayout.wander(from: layout, scene: scene)
        let state = contentState(scene: scene,
                                 temperatureC: currentWeather?.temperatureC ?? 20)
        await activity.update(
            .init(state: state, staleDate: Date(timeIntervalSinceNow: 3 * 3600))
        )
    }

    // MARK: - Refresh (called on launch/foreground and from background task)

    @discardableResult
    func refresh() async -> Bool {
        guard !isRefreshing else { return false }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let location = try await LocationService.shared.currentLocation()
            placeName = nil
            let weather = try await WeatherService.fetch(for: location.coordinate)
            currentWeather = weather
            lastRefresh = .now
            errorMessage = nil
            await reverseGeocode(location)
            await pushUpdate(weather)
            return true
        } catch LocationService.LocationError.denied {
            errorMessage = "Location access is denied. Enable it in Settings to get local weather."
            return false
        } catch {
            errorMessage = "Weather refresh failed: \(error.localizedDescription)"
            return false
        }
    }

    private func pushUpdate(_ weather: CurrentWeather) async {
        guard let activity else { return }
        // Every update doubles as a wander tick so the dog also moves on
        // background refreshes, not just on the foreground timer.
        layout = SceneLayout.wander(from: layout, scene: weather.scene)
        let state = contentState(scene: weather.scene, temperatureC: weather.temperatureC)
        await activity.update(
            .init(state: state, staleDate: Date(timeIntervalSinceNow: 3 * 3600))
        )
    }

    private func contentState(
        scene: PupScene,
        temperatureC: Double
    ) -> PupActivityAttributes.ContentState {
        .init(
            scene: scene,
            temperatureC: temperatureC,
            updatedAt: .now,
            layout: layout
        )
    }

    private func reverseGeocode(_ location: CLLocation) async {
        let geocoder = CLGeocoder()
        if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
            placeName = placemark.locality ?? placemark.subAdministrativeArea
        } else {
            placeName = nil
        }
    }

    private func syncActivityState() {
        isActivityRunning = !Activity<PupActivityAttributes>.activities.isEmpty
    }
}
