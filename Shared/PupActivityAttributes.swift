import ActivityKit
import Foundation

struct PupActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var scene: PupScene
        var temperatureC: Double
        var updatedAt: Date
        /// Where the dog is and what it's doing. Each activity update sends a
        /// fresh layout, which is what makes the dog wander around the field.
        var layout: SceneLayout
    }

    var startedAt: Date
}
