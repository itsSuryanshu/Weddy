import SwiftUI

/// A weather scene. The scene picks the palette, lighting, weather particles
/// and which behaviours the dog can do; everything is drawn procedurally in
/// `PupSceneView` from pixel-sprite models.
enum PupScene: String, Codable, CaseIterable, Hashable {
    case clearDay
    case warmDay
    case cloudy
    case rain
    case thunder
    case snow
    case fog
    case night

    var label: String {
        switch self {
        case .clearDay: "Sunny"
        case .warmDay: "Sunny & Butterflies"
        case .cloudy: "Cloudy"
        case .rain: "Rain"
        case .thunder: "Thunderstorm"
        case .snow: "Snow"
        case .fog: "Fog"
        case .night: "Clear Night"
        }
    }

    var symbolName: String {
        switch self {
        case .clearDay: "sun.max.fill"
        case .warmDay: "sun.max.fill"
        case .cloudy: "cloud.fill"
        case .rain: "cloud.rain.fill"
        case .thunder: "cloud.bolt.rain.fill"
        case .snow: "cloud.snow.fill"
        case .fog: "cloud.fog.fill"
        case .night: "moon.stars.fill"
        }
    }

    var skyTopHex: UInt32 {
        switch self {
        case .clearDay, .warmDay: 0x1280F7
        case .cloudy: 0x687D96
        case .rain: 0x293B4F
        case .thunder: 0x0F1224
        case .snow: 0x75A6D6
        case .fog: 0x8FA3AD
        case .night: 0x080F36
        }
    }

    var skyBottomHex: UInt32 {
        switch self {
        case .clearDay, .warmDay: 0x85CCFF
        case .cloudy: 0xCFD9E0
        case .rain: 0x8296AB
        case .thunder: 0x4F546B
        case .snow: 0xEBF7FF
        case .fog: 0xE3EBED
        case .night: 0x38528A
        }
    }

    var skyTop: Color { Color(px: skyTopHex) }
    var skyBottom: Color { Color(px: skyBottomHex) }

    /// Ink for the weather text over the scene: white everywhere except the
    /// near-white snow field, where it flips to a deep slate blue.
    var ink: Color {
        self == .snow ? Color(px: 0x33628F) : .white
    }

    /// Maps an Open-Meteo WMO weather code + daylight flag + temperature to a scene.
    static func from(wmoCode: Int, isDay: Bool, temperatureC: Double) -> PupScene {
        let base: PupScene
        switch wmoCode {
        case 0...2:
            base = .clearDay
        case 3:
            base = .cloudy
        case 45, 48:
            base = .fog
        case 51...67, 80...82:
            base = .rain
        case 71...77, 85, 86:
            base = .snow
        case 95...99:
            base = .thunder
        default:
            base = .cloudy
        }
        if !isDay {
            // Precipitation still reads clearly at night; calm scenes become night.
            switch base {
            case .clearDay, .cloudy, .fog: return .night
            default: return base
            }
        }
        // Butterflies on sunny or partly-cloudy days (WMO 0-2) when warm enough.
        if base == .clearDay && temperatureC >= 20 {
            return .warmDay
        }
        return base
    }
}
