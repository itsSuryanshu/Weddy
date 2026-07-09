import Foundation

/// Where the location name sits on the Live Activity lock-screen view.
/// Selected in Settings and carried inside the content state, same as
/// `SceneRenderStyle`.
enum LocationLabelPosition: String, Codable, CaseIterable, Hashable {
    case topLeft
    case bottomLeft
    case bottomCenter

    var label: String {
        switch self {
        case .topLeft: "Top Left"
        case .bottomLeft: "Bottom Left"
        case .bottomCenter: "Bottom Center"
        }
    }
}
