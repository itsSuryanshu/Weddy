import Foundation

/// How the weather scene is drawn. Selected in Settings and carried inside
/// the Live Activity content state so the widget needs no shared storage.
enum SceneRenderStyle: String, Codable, CaseIterable, Hashable {
    /// The 32-bit pixel-art look (vector `Path`s).
    case normal
    /// Colored ASCII characters, terminal-art style.
    case ascii

    var label: String {
        switch self {
        case .normal: "Normal"
        case .ascii: "ASCII"
        }
    }
}
