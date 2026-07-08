import CoreLocation
import Foundation

/// One result row from Open-Meteo's geocoding search.
struct GeocodedCity: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let country_code: String?
    let admin1: String?
}

extension GeocodedCity {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayName: String { name }

    /// "Illinois, United States" — disambiguates same-named cities.
    var disambiguationLine: String {
        [admin1, country].compactMap { $0 }.joined(separator: ", ")
    }
}

/// Worldwide city search against Open-Meteo's free geocoding API
/// (search-as-you-type; there is no bulk/enumerable city list).
enum GeocodingService {
    private struct Response: Decodable {
        let results: [GeocodedCity]?
    }

    static func search(query: String) async throws -> [GeocodedCity] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            .init(name: "name", value: query),
            .init(name: "count", value: "15"),
            .init(name: "language", value: "en"),
            .init(name: "format", value: "json"),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.results ?? []
    }
}
