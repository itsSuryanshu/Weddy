import SwiftUI

/// Shared band geometry for the 60-row art grid, used by both the pixel and
/// the ASCII composers so the two styles can never drift apart.
enum SceneGeometry {
    /// Art grid height in pixels; width adapts to the view.
    static let rows = 60
    /// Where the hills meet the field.
    static let horizonY = 34
    /// Top of the foreground grass band.
    static let frontY = 52
    /// Where the dog's paws rest (slightly inside the front grass for depth).
    static let feetY = 55
}

/// Per-scene colors and feature flags consumed by the scene composers.
struct ScenePalette {
    var farHill: UInt32
    var hill: UInt32
    var hillEdge: UInt32
    var field: UInt32
    var fieldLight: UInt32
    var front: UInt32
    var frontBlade: UInt32
    var shadow: UInt32
    var rainA: UInt32 = 0xA8CFF0
    var rainB: UInt32 = 0x7FB3E3
    var showsSun = false
    var showsMoon = false
    var showsStars = false
    var cloudCount = 0
    var stormClouds = false
    var darkTrees = false
    var rain = false
    var snow = false
    var fogBands = false
    var lightning = false
    var butterflies = false
    var flowers = false

    static func `for`(_ scene: PupScene) -> ScenePalette {
        switch scene {
        case .clearDay:
            ScenePalette(farHill: 0x63C96B, hill: 0x3FA34D, hillEdge: 0x2C7A3B,
                         field: 0x6FD44E, fieldLight: 0x8CE06B,
                         front: 0x2F9E44, frontBlade: 0x54C05A, shadow: 0x3E9E3F,
                         showsSun: true, cloudCount: 2, flowers: true)
        case .warmDay:
            ScenePalette(farHill: 0x63C96B, hill: 0x3FA34D, hillEdge: 0x2C7A3B,
                         field: 0x6FD44E, fieldLight: 0x8CE06B,
                         front: 0x2F9E44, frontBlade: 0x54C05A, shadow: 0x3E9E3F,
                         showsSun: true, cloudCount: 2, butterflies: true, flowers: true)
        case .cloudy:
            ScenePalette(farHill: 0x57AE63, hill: 0x389447, hillEdge: 0x27703A,
                         field: 0x63C24C, fieldLight: 0x7CD063,
                         front: 0x2A8E3E, frontBlade: 0x4AAE52, shadow: 0x358E38,
                         cloudCount: 5, flowers: true)
        case .rain:
            ScenePalette(farHill: 0x2E7A44, hill: 0x255F36, hillEdge: 0x1B4A29,
                         field: 0x3C9145, fieldLight: 0x4EA455,
                         front: 0x1E6B33, frontBlade: 0x2F8442, shadow: 0x1E6B33,
                         cloudCount: 3, stormClouds: true, darkTrees: true, rain: true)
        case .thunder:
            ScenePalette(farHill: 0x235B37, hill: 0x1A4A2C, hillEdge: 0x123B21,
                         field: 0x2C7038, fieldLight: 0x357E42,
                         front: 0x143F22, frontBlade: 0x1F5A31, shadow: 0x143F22,
                         rainA: 0x9DB8D9, rainB: 0x7A97BD,
                         cloudCount: 3, stormClouds: true, darkTrees: true,
                         rain: true, lightning: true)
        case .rainNight:
            ScenePalette(farHill: darken(0x2E7A44, 0.72), hill: darken(0x255F36, 0.72), hillEdge: darken(0x1B4A29, 0.72),
                         field: darken(0x3C9145, 0.72), fieldLight: darken(0x4EA455, 0.72),
                         front: darken(0x1E6B33, 0.72), frontBlade: darken(0x2F8442, 0.72), shadow: darken(0x1E6B33, 0.72),
                         showsMoon: true, cloudCount: 3, stormClouds: true, darkTrees: true, rain: true)
        case .thunderNight:
            ScenePalette(farHill: darken(0x235B37, 0.78), hill: darken(0x1A4A2C, 0.78), hillEdge: darken(0x123B21, 0.78),
                         field: darken(0x2C7038, 0.78), fieldLight: darken(0x357E42, 0.78),
                         front: darken(0x143F22, 0.78), frontBlade: darken(0x1F5A31, 0.78), shadow: darken(0x143F22, 0.78),
                         rainA: darken(0x9DB8D9, 0.8), rainB: darken(0x7A97BD, 0.8),
                         showsMoon: true, cloudCount: 3, stormClouds: true, darkTrees: true,
                         rain: true, lightning: true)
        case .snow:
            ScenePalette(farHill: 0xCFE6F7, hill: 0xBFDCF2, hillEdge: 0x9CC4E4,
                         field: 0xF2FAFF, fieldLight: 0xFFFFFF,
                         front: 0xD6EBFA, frontBlade: 0xEAF6FF, shadow: 0xBFDCF2,
                         cloudCount: 3, snow: true)
        case .snowNight:
            // Hand-tuned rather than `darken()`: uniformly scaling the
            // near-white day-snow palette desaturates it to flat grey. A
            // moonlit blue tint keeps it reading as snow, not pavement.
            ScenePalette(farHill: 0x3E5C78, hill: 0x2F4A64, hillEdge: 0x22384F,
                         field: 0x4A6C8C, fieldLight: 0x6B90B4,
                         front: 0x35516C, frontBlade: 0x496F90, shadow: 0x22384F,
                         showsMoon: true, cloudCount: 3, darkTrees: true, snow: true)
        case .fog:
            ScenePalette(farHill: 0x7FA98B, hill: 0x6A9678, hillEdge: 0x557F63,
                         field: 0x86B292, fieldLight: 0x97C2A2,
                         front: 0x5E8A6C, frontBlade: 0x74A181, shadow: 0x5E8A6C,
                         fogBands: true)
        case .fogNight:
            ScenePalette(farHill: darken(0x7FA98B, 0.5), hill: darken(0x6A9678, 0.5), hillEdge: darken(0x557F63, 0.5),
                         field: darken(0x86B292, 0.5), fieldLight: darken(0x97C2A2, 0.5),
                         front: darken(0x5E8A6C, 0.5), frontBlade: darken(0x74A181, 0.5), shadow: darken(0x5E8A6C, 0.5),
                         showsMoon: true, darkTrees: true, fogBands: true)
        case .night:
            ScenePalette(farHill: 0x1C5B34, hill: 0x144A28, hillEdge: 0x0E3A1F,
                         field: 0x1F6B38, fieldLight: 0x2A7C44,
                         front: 0x0F4423, frontBlade: 0x1B5C31, shadow: 0x0F4423,
                         showsMoon: true, showsStars: true, darkTrees: true)
        }
    }
}

/// Dims a day palette color for its night counterpart, keeping the same hue
/// so night scenes read as "the same place after dark" rather than a
/// different color scheme.
func darken(_ hex: UInt32, _ factor: Double) -> UInt32 {
    func scale(_ shift: UInt32) -> UInt32 {
        let c = Double((hex >> shift) & 0xFF)
        return UInt32((c * factor).rounded()) << shift
    }
    return scale(16) | scale(8) | scale(0)
}

func lerpHex(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
    func mix(_ shift: UInt32) -> UInt32 {
        let ca = Double((a >> shift) & 0xFF)
        let cb = Double((b >> shift) & 0xFF)
        return UInt32((ca + (cb - ca) * t).rounded()) << shift
    }
    return mix(16) | mix(8) | mix(0)
}
