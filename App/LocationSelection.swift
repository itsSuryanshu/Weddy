import Foundation

/// What weather source the app should use: live GPS, or a manually chosen city.
enum LocationSelection: Codable, Equatable {
    case gps
    case manual(GeocodedCity)
}

/// Persists the chosen location across launches. UserDefaults + Codable,
/// the simplest correct approach given no persistence layer exists yet.
enum LocationSelectionStore {
    private static let key = "com.pupweather.selectedLocation"

    static func load() -> LocationSelection {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(LocationSelection.self, from: data)
        else { return .gps }
        return decoded
    }

    static func save(_ selection: LocationSelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
