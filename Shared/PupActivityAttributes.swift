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
        /// Global user-chosen weather-badge scale. Optional so payloads
        /// written by builds without the key still decode; nil means 1.0.
        var badgeScale: Double?
        /// Global user-chosen scene render style, stored as the raw string so
        /// old payloads (nil) and values from future builds both fall back to
        /// `.normal` instead of failing the whole ContentState decode.
        var sceneStyle: String?

        var resolvedBadgeScale: Double { badgeScale ?? 1.0 }
        var resolvedSceneStyle: SceneRenderStyle {
            sceneStyle.flatMap(SceneRenderStyle.init(rawValue:)) ?? .normal
        }
    }

    var startedAt: Date
    /// Matches `TrackedLocation.id` / `LocationSelection.stableID`. Fixed at
    /// creation — attributes can't be edited after `Activity.request`, so
    /// changing what a location points to means ending this activity and
    /// starting a new one, never mutating this in place.
    var locationID: String
    var locationName: String
}
