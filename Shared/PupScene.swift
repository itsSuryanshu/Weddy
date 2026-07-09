import SwiftUI

/// A weather condition independent of time of day — what the scene picker
/// exposes. Combine with a day/night flag via `PupScene.scene(for:night:)`.
enum PupCondition: String, CaseIterable, Hashable {
    case clear
    case cloudy
    case rain
    case thunder
    case snow
    case fog

    var label: String {
        switch self {
        case .clear: "Clear"
        case .cloudy: "Cloudy"
        case .rain: "Rain"
        case .thunder: "Thunderstorm"
        case .snow: "Snow"
        case .fog: "Fog"
        }
    }

    var symbolName: String {
        switch self {
        case .clear: "sun.max.fill"
        case .cloudy: "cloud.fill"
        case .rain: "cloud.rain.fill"
        case .thunder: "cloud.bolt.rain.fill"
        case .snow: "cloud.snow.fill"
        case .fog: "cloud.fog.fill"
        }
    }
}

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
        case .clearDay, .warmDay: "Sunny"
        case .night: "Clear"
        default: condition.label
        }
    }

    var condition: PupCondition {
        switch self {
        case .clearDay, .warmDay, .night: .clear
        case .cloudy: .cloudy
        case .rain, .rainNight: .rain
        case .thunder, .thunderNight: .thunder
        case .snow, .snowNight: .snow
        case .fog, .fogNight: .fog
        }
    }

    var isNight: Bool {
        switch self {
        case .rainNight, .thunderNight, .snowNight, .fogNight, .night: true
        default: false
        }
    }

    /// The scene previewed for a picker selection. Clear days show the richer
    /// butterflies variant; cloudy nights collapse into the clear night scene,
    /// mirroring what `from(wmoCode:isDay:temperatureC:)` does with live weather.
    static func scene(for condition: PupCondition, night: Bool) -> PupScene {
        switch condition {
        case .clear: night ? .night : .warmDay
        case .cloudy: night ? .night : .cloudy
        case .rain: night ? .rainNight : .rain
        case .thunder: night ? .thunderNight : .thunder
        case .snow: night ? .snowNight : .snow
        case .fog: night ? .fogNight : .fog
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

    /// Style-aware ink: the ASCII scene sits on a terminal-dark backdrop in
    /// every scene, so its overlay text is always white.
    func ink(for style: SceneRenderStyle) -> Color {
        style == .ascii ? .white : ink
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
