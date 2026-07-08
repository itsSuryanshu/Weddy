import Foundation

/// What the dog is doing in the scene.
enum DogAction: String, Codable, Hashable {
    case sit
    case trot
    case sniff
    case jump
    case sleep
}

/// The dynamic part of a scene: where the dog is, what it's doing, and the
/// seed that scatters the scenery. This travels in the Live Activity content
/// state, so each activity update makes the dog wander somewhere new while
/// the world (trees, clouds, stars) stays put.
struct SceneLayout: Codable, Hashable {
    /// Scatters trees, clouds, stars, flowers. Stable across wander updates.
    var worldSeed: UInt64
    /// Re-rolled on every wander: flutters the butterflies to fresh spots in
    /// front of the dog, so each update reads as the dog chasing them.
    var flutterSeed: UInt64
    /// Dog anchor across the field, 0 (left) … 1 (right).
    var dogUnit: Double
    var dogFacesLeft: Bool
    var dogAction: DogAction

    /// The moves the dog can pull in a given scene, weighted by repetition.
    static func actions(for scene: PupScene) -> [DogAction] {
        switch scene {
        case .clearDay: [.trot, .sit, .sniff, .trot, .sit]
        case .warmDay: [.jump, .jump, .trot, .jump]  // frolics with the butterflies
        case .cloudy: [.sit, .trot, .sniff, .sit]
        case .rain, .thunder: [.sit]
        case .snow: [.jump, .trot, .sit]
        case .fog: [.sniff, .sit, .sniff]
        case .night: [.sleep]
        }
    }

    static func makeInitial(for scene: PupScene) -> SceneLayout {
        wander(from: nil, scene: scene)
    }

    /// A fixed layout for previews and tests.
    static func preview(for scene: PupScene) -> SceneLayout {
        SceneLayout(worldSeed: 0xC0FFEE,
                    flutterSeed: 0xF107,
                    dogUnit: 0.38,
                    dogFacesLeft: false,
                    dogAction: actions(for: scene)[0])
    }

    /// Next spot for the dog. Keeps the world seed so scenery doesn't
    /// reshuffle, and makes the dog actually travel (no tiny shuffles).
    static func wander(from previous: SceneLayout?, scene: PupScene) -> SceneLayout {
        var rng = SystemRandomNumberGenerator()
        let seed = previous?.worldSeed ?? UInt64.random(in: 1...UInt64.max, using: &rng)

        var unit = Double.random(in: 0.05...0.95, using: &rng)
        if let last = previous?.dogUnit, abs(unit - last) < 0.18 {
            // Hop to the other side of the previous spot instead.
            unit = last > 0.5 ? max(0.05, last - 0.35) : min(0.95, last + 0.35)
        }
        let facesLeft: Bool
        if let last = previous?.dogUnit {
            facesLeft = unit < last
        } else {
            facesLeft = Bool.random(using: &rng)
        }
        let options = actions(for: scene)
        let action = options[Int.random(in: 0..<options.count, using: &rng)]
        return SceneLayout(worldSeed: seed,
                           flutterSeed: UInt64.random(in: 1...UInt64.max, using: &rng),
                           dogUnit: unit,
                           dogFacesLeft: facesLeft,
                           dogAction: action)
    }
}
