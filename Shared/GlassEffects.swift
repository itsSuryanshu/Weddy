import SwiftUI

/// Liquid Glass wasn't introduced until iOS 26; the app supports back to 17,
/// so older runtimes fall back to a tinted material that reads the same way.
private struct GlassButtonModifier<S: InsettableShape>: ViewModifier {
    var tint: Color
    var shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(tint.opacity(0.6)).interactive(), in: shape)
        } else {
            content
                .background(tint.opacity(0.35), in: shape)
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(tint.opacity(0.5), lineWidth: 1))
                .shadow(radius: 4, y: 2)
        }
    }
}

extension View {
    func glassButton<S: InsettableShape>(tint: Color = .orange, in shape: S = Circle()) -> some View {
        modifier(GlassButtonModifier(tint: tint, shape: shape))
    }
}
