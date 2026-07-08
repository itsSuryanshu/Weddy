import CoreLocation
import Foundation

struct CurrentWeather {
    var temperatureC: Double
    var wmoCode: Int
    var isDay: Bool

    var scene: PupScene {
        .from(wmoCode: wmoCode, isDay: isDay, temperatureC: temperatureC)
    }
}

/// Fetches current conditions from Open-Meteo (free, no API key).
enum WeatherService {
    private struct Response: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
            let is_day: Int
        }
        let current: Current
    }

    static func fetch(for coordinate: CLLocationCoordinate2D) async throws -> CurrentWeather {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(format: "%.4f", coordinate.latitude)),
            .init(name: "longitude", value: String(format: "%.4f", coordinate.longitude)),
            .init(name: "current", value: "temperature_2m,weather_code,is_day"),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return CurrentWeather(
            temperatureC: decoded.current.temperature_2m,
            wmoCode: decoded.current.weather_code,
            isDay: decoded.current.is_day == 1
        )
    }
}
