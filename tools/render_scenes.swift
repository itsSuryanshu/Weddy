// Renders every weather scene to tools/out/<scene>.png so the pixel art can
// be reviewed without booting a simulator. Build & run:
//
//   swiftc -parse-as-library -D RENDER_TOOL \
//       tools/render_scenes.swift Shared/PixelArt.swift Shared/PupSprites.swift \
//       Shared/PupScene.swift Shared/SceneLayout.swift Shared/PupSceneView.swift \
//       -o /tmp/render_scenes && /tmp/render_scenes
//
// (The Shared files are pure SwiftUI, so they compile for macOS as-is.)

import AppKit
import SwiftUI

/// A single sprite blown up for close review.
private struct SpriteCard: View {
    let sprite: PixelSprite
    let pixel: CGFloat

    var body: some View {
        var painter = PixelPainter(pixel: pixel)
        painter.stamp(sprite, x: 0, y: 0)
        return PixelPaintingView(layers: painter.layers)
            .frame(width: CGFloat(sprite.width) * pixel,
                   height: CGFloat(sprite.height) * pixel,
                   alignment: .topLeading)
            .background(Color(px: 0x9BD0F5))
    }
}

@main
struct RenderScenes {
    @MainActor
    static func main() {
        let outDir = URL(fileURLWithPath: "tools/out", isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let sprites: [(String, PixelSprite)] = [
            ("dogSit", PupSprites.dogSit),
            ("dogTrot", PupSprites.dogTrot),
            ("dogJump", PupSprites.dogJump),
            ("dogSniff", PupSprites.dogSniff),
            ("dogSleep", PupSprites.dogSleep),
            ("butterfly", PupSprites.butterflyBlue),
            ("tree", PupSprites.tree),
        ]
        for (name, sprite) in sprites {
            write(SpriteCard(sprite: sprite, pixel: 12), to: outDir, name: "sprite-\(name)")
        }

        for scene in PupScene.allCases {
            let view = PupSceneView(scene: scene, layout: .preview(for: scene), minHeight: 120)
                .frame(width: 380, height: 120)
            write(view, to: outDir, name: scene.rawValue)
        }
    }

    @MainActor
    private static func write(_ view: some View, to dir: URL, name: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("FAILED to render \(name)")
            return
        }
        let url = dir.appendingPathComponent("\(name).png")
        try? png.write(to: url)
        print("wrote \(url.path)")
    }
}
