import SwiftUI

/// Liquid Glass wasn't introduced until iOS 26; the app supports back to 17,
/// so older runtimes fall back to a tinted material that reads the same way.
private struct GlassButtonModifier<S: InsettableShape>: ViewModifier {
    var tint: Color?
    var shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            let glass = tint.map { Glass.regular.tint($0.opacity(0.6)) } ?? .regular
            content.glassEffect(glass.interactive(), in: shape)
        } else if let tint {
            content
                .background(tint.opacity(0.35), in: shape)
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(tint.opacity(0.5), lineWidth: 1))
                .shadow(radius: 4, y: 2)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                .shadow(radius: 4, y: 2)
        }
    }
}

extension View {
    func glassButton<S: InsettableShape>(tint: Color? = nil, in shape: S = Circle()) -> some View {
        modifier(GlassButtonModifier(tint: tint, shape: shape))
    }
}
