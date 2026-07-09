import Foundation

/// What weather source the app should use: live GPS, or a manually chosen city.
enum LocationSelection: Codable, Equatable {
    case gps
    case manual(GeocodedCity)
}

extension LocationSelection {
    /// Stable identity independent of transient app state, used to key
    /// per-location Live Activities and dictionaries.
    var stableID: String {
        switch self {
        case .gps: return "gps"
        case .manual(let city): return "city-\(city.id)"
        }
    }
}

/// One location the user is tracking a Live Activity for. `isPrimary` marks
/// the original/current location, which is always pinned first and can't be
/// removed.
struct TrackedLocation: Codable, Equatable, Identifiable {
    var selection: LocationSelection
    var isPrimary: Bool
    var addedAt: Date = .now
    /// Hidden locations stay tracked (weather still refreshes for the in-app
    /// card) but their Live Activity is ended and never auto-restarted until
    /// the user unhides them.
    var isHidden: Bool = false

    var id: String { selection.stableID }
}

extension TrackedLocation {
    private enum CodingKeys: String, CodingKey {
        case selection, isPrimary, addedAt, isHidden
    }

    /// Custom decode (in an extension, so the memberwise init survives) that
    /// tolerates records saved before `isHidden` existed.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selection = try container.decode(LocationSelection.self, forKey: .selection)
        isPrimary = try container.decode(Bool.self, forKey: .isPrimary)
        addedAt = try container.decodeIfPresent(Date.self, forKey: .addedAt) ?? .now
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
    }
}

/// Persists the set of tracked locations across launches. UserDefaults +
/// Codable, the simplest correct approach given no persistence layer exists yet.
enum TrackedLocationStore {
    private static let key = "com.pupweather.trackedLocations.v2"

    static func load() -> [TrackedLocation] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TrackedLocation].self, from: data)
        else { return [] }
        return decoded
    }

    static func save(_ locations: [TrackedLocation]) {
        guard let data = try? JSONEncoder().encode(locations) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
