import CoreLocation

/// One-shot, coarse location fixes for weather lookups.
@MainActor
final class LocationService {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private let delegateProxy = DelegateProxy()
    private var continuations: [CheckedContinuation<CLLocation, Error>] = []
    private var ignoredStaleUpdate = false
    private let maximumLocationAge: TimeInterval = 5 * 60

    enum LocationError: Error {
        case denied
        case unavailable
    }

    private init() {
        delegateProxy.owner = self
        manager.delegate = delegateProxy
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = kCLDistanceFilterNone
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func currentLocation() async throws -> CLLocation {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            throw LocationError.denied
        case .notDetermined:
            // Ask for permission; the authorization callback triggers the
            // actual location request once granted.
            return try await withCheckedThrowingContinuation { cont in
                continuations.append(cont)
                ignoredStaleUpdate = false
                manager.requestWhenInUseAuthorization()
            }
        default:
            return try await withCheckedThrowingContinuation { cont in
                continuations.append(cont)
                ignoredStaleUpdate = false
                manager.requestLocation()
            }
        }
    }

    fileprivate func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            if !continuations.isEmpty {
                manager.requestLocation()
            }
        case .denied, .restricted:
            finish(.failure(LocationError.denied))
        default:
            break
        }
    }

    fileprivate func handleLocationUpdate(_ locations: [CLLocation]) {
        if let loc = locations.last(where: isFreshLocation) {
            finish(.success(loc))
        } else if !ignoredStaleUpdate {
            ignoredStaleUpdate = true
            manager.requestLocation()
        } else {
            finish(.failure(LocationError.unavailable))
        }
    }

    fileprivate func handleLocationFailure(_ error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        let pending = continuations
        continuations.removeAll()
        ignoredStaleUpdate = false
        for cont in pending {
            cont.resume(with: result)
        }
    }

    private func isFreshLocation(_ location: CLLocation) -> Bool {
        location.horizontalAccuracy >= 0
            && location.horizontalAccuracy <= 5_000
            && abs(location.timestamp.timeIntervalSinceNow) <= maximumLocationAge
    }
}

/// Receives CLLocationManager callbacks off the main actor and forwards to LocationService.
private final class DelegateProxy: NSObject, CLLocationManagerDelegate {
    weak var owner: LocationService?

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak owner] in
            owner?.handleAuthorizationChange(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locations = locations
        Task { @MainActor [weak owner] in
            owner?.handleLocationUpdate(locations)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak owner] in
            owner?.handleLocationFailure(error)
        }
    }
}
