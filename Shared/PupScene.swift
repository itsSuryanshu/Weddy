import SwiftUI

/// A weather scene. The scene picks the palette, lighting, weather particles
/// and which behaviours the dog can do; everything is drawn procedurally in
/// `PupSceneView` from pixel-sprite models.
enum PupScene: String, Codable, CaseIterable, Hashable {
    case clearDay
    case warmDay
    case cloudy
    case rain
    case rainNight
    case thunder
    case thunderNight
    case snow
    case snowNight
    case fog
    case fogNight
    case night

    var label: String {
        switch self {
        case .clearDay: "Sunny"
        case .warmDay: "Sunny & Butterflies"
        case .cloudy: "Cloudy"
        case .rain: "Rain"
        case .rainNight: "Night Rain"
        case .thunder: "Thunderstorm"
        case .thunderNight: "Night Thunderstorm"
        case .snow: "Snow"
        case .snowNight: "Night Snow"
        case .fog: "Fog"
        case .fogNight: "Night Fog"
        case .night: "Clear Night"
        }
    }

    var symbolName: String {
        switch self {
        case .clearDay: "sun.max.fill"
        case .warmDay: "sun.max.fill"
        case .cloudy: "cloud.fill"
        case .rain: "cloud.rain.fill"
        case .rainNight: "cloud.moon.rain.fill"
        case .thunder: "cloud.bolt.rain.fill"
        case .thunderNight: "cloud.moon.bolt.fill"
        case .snow: "cloud.snow.fill"
        case .snowNight: "cloud.snow.fill"
        case .fog: "cloud.fog.fill"
        case .fogNight: "cloud.fog.fill"
        case .night: "moon.stars.fill"
        }
    }

    var skyTopHex: UInt32 {
        switch self {
        case .clearDay, .warmDay: 0x1280F7
        case .cloudy: 0x687D96
        case .rain: 0x293B4F
        case .rainNight: 0x121A30
        case .thunder: 0x0F1224
        case .thunderNight: 0x0A0C1C
        case .snow: 0x75A6D6
        case .snowNight: 0x142440
        case .fog: 0x8FA3AD
        case .fogNight: 0x1C2732
        case .night: 0x080F36
        }
    }

    var skyBottomHex: UInt32 {
        switch self {
        case .clearDay, .warmDay: 0x85CCFF
        case .cloudy: 0xCFD9E0
        case .rain: 0x8296AB
        case .rainNight: 0x3A4D6B
        case .thunder: 0x4F546B
        case .thunderNight: 0x363A54
        case .snow: 0xEBF7FF
        case .snowNight: 0x395480
        case .fog: 0xE3EBED
        case .fogNight: 0x3D4854
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
            // Calm scenes collapse into the plain clear-night scene, but
            // precipitation gets its own night variant so it still reads as
            // both "dark out" (moon/stars, dim palette) and "raining" (etc).
            switch base {
            case .clearDay, .cloudy: return .night
            case .fog: return .fogNight
            case .rain: return .rainNight
            case .snow: return .snowNight
            case .thunder: return .thunderNight
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
