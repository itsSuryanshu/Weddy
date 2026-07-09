import SwiftUI

/// Renders the weather scene as colored ASCII characters — the terminal-art
/// alternative to the pixel `SceneComposer`. It works in the same 60-row
/// virtual pixel space with the same column count and consumes `PixelRandom`
/// in the same order per element, so a given `worldSeed` places trees,
/// clouds, stars and the dog in the same spots in both styles.
struct AsciiSceneComposer {
    let scene: PupScene
    let layout: SceneLayout
    /// Width in points of one character cell (== one virtual pixel).
    let cellW: CGFloat
    let cols: Int
    let reservedTrailingWidth: CGFloat

    private let horizonY = SceneGeometry.horizonY
    private let frontY = SceneGeometry.frontY
    private let feetY = SceneGeometry.feetY
    private let style: ScenePalette

    /// Same pose-dependent scale as the pixel composer.
    private var dogScale: Double {
        layout.dogAction == .sit ? 1.2 : 1.5
    }

    init(scene: PupScene, layout: SceneLayout, width: CGFloat, height: CGFloat,
         reservedTrailingWidth: CGFloat = 0) {
        self.scene = scene
        self.layout = layout
        self.cellW = height / CGFloat(SceneGeometry.rows)
        self.cols = Int((width / max(cellW, 0.5)).rounded(.up))
        self.reservedTrailingWidth = reservedTrailingWidth
        self.style = ScenePalette.for(scene)
    }

    /// Character cell height in points (2 virtual pixels).
    var cellH: CGFloat { cellW * CGFloat(AsciiPainter.pxPerRow) }
    /// Font size whose SF Mono advance (0.6 em) equals one cell width.
    var fontSize: CGFloat { cellW / 0.6 }

    func rowStrings() -> [AttributedString] {
        var p = AsciiPainter(cols: cols, pxRows: SceneGeometry.rows)
        var rng = PixelRandom(seed: layout.worldSeed)

        paintSky(&p)
        if style.showsStars { paintStars(&p, rng: &rng) }
        if style.showsSun { p.stamp(PupSprites.sun, x: Double(cols - 20), y: 2) }
        if style.showsMoon { p.stamp(PupSprites.moon, x: Double(cols - 17), y: 4) }
        paintClouds(&p, rng: &rng)
        paintHills(&p, rng: &rng)
        paintField(&p, rng: &rng)
        paintDogShadow(&p)
        paintDog(&p)

        var fg = PixelRandom(seed: layout.worldSeed ^ 0xF06E6006)
        paintFrontGrass(&p, rng: &fg)
        if style.rain { paintRain(&p, rng: &fg) }
        if style.snow { paintSnow(&p, rng: &fg) }
        if style.lightning {
            let x = fg.double(12...(Double(cols) * 0.5))
            p.stamp(PupSprites.lightning, x: x, y: 13, scale: 1.5)
        }
        if style.fogBands { paintFog(&p, rng: &fg) }

        return p.rowStrings()
    }

    // MARK: Background

    private func paintSky(_ p: inout AsciiPainter) {
        let bands = 6
        let bandHeight = Double(SceneGeometry.rows) / Double(bands)
        for py in stride(from: 0, to: SceneGeometry.rows, by: AsciiPainter.pxPerRow) {
            let band = min(Int(Double(py) / bandHeight), bands - 1)
            let t = Double(band) / Double(bands - 1)
            let color = Color(px: lerpHex(scene.skyTopHex, scene.skyBottomHex, t))
            for x in 0..<cols {
                // Fixed dither (no RNG — the pixel sky draws none either).
                let sparkle = (x &* 7 &+ py &* 3) % 11 == 0
                p.put(Double(x), Double(py), glyph: sparkle ? "`" : ":", color: color)
            }
        }
    }

    private func paintStars(_ p: inout AsciiPainter, rng: inout PixelRandom) {
        let palette: [UInt32] = [0xFFFFFF, 0xBFD4FF, 0xFFE9A8]
        for _ in 0..<(cols / 4) {
            let x = Double(rng.int(0...(cols - 1)))
            let y = Double(rng.int(0...(horizonY - 8)))
            let color = Color(px: rng.pick(palette))
            if rng.bool(0.2) {
                p.put(x, y, glyph: "+", color: color)
            } else {
                p.put(x, y, glyph: ".", color: color)
            }
        }
    }

    private func paintClouds(_ p: inout AsciiPainter, rng: inout PixelRandom) {
        guard style.cloudCount > 0 else { return }
        let sprite = style.stormClouds ? PupSprites.stormCloud : PupSprites.cloud
        let small = style.stormClouds ? PupSprites.stormCloud : PupSprites.cloudSmall
        let maxX = style.showsSun ? Double(cols) * 0.62 : Double(cols - 24)
        let slot = max(maxX / Double(style.cloudCount), 26)
        for i in 0..<style.cloudCount {
            let big = rng.bool(0.55)
            let x = Double(i) * slot + rng.double(0...(slot * 0.45))
            let y = rng.double(1...11)
            p.stamp(big ? sprite : small, x: x, y: y)
        }
    }

    private func paintHills(_ p: inout AsciiPainter, rng: inout PixelRandom) {
        let phase1 = rng.double(0...6.28)
        let phase2 = rng.double(0...6.28)
        let far = Color(px: style.farHill)
        let near = Color(px: style.hill)
        let edge = Color(px: style.hillEdge)

        for x in 0..<cols {
            let fx = Double(x)
            let farTop = 27.0 + (3.2 * sin(fx * 0.045 + phase1)).rounded()
            p.fill(fx, farTop, 1, Double(horizonY) - farTop + 1, glyph: "+", color: far)
        }
        for x in 0..<cols {
            let fx = Double(x)
            let top = 31.0 + (2.0 * sin(fx * 0.09 + phase2) + 1.2 * sin(fx * 0.031 + phase1)).rounded()
            p.put(fx, top, glyph: "~", color: edge)
            p.fill(fx, top + 1, 1, Double(horizonY) - top, glyph: "#", color: near)
        }

        let tree = style.darkTrees ? PupSprites.treeNight : PupSprites.tree
        let small = style.darkTrees ? PupSprites.treeSmallNight : PupSprites.treeSmall
        let count = max(2, cols / 45)
        let slot = Double(cols) / Double(count)
        for i in 0..<count {
            let big = rng.bool(0.5)
            let sprite = big ? tree : small
            let x = Double(i) * slot + rng.double(2...(max(slot - Double(sprite.width) - 2, 3)))
            let y = Double(horizonY - sprite.height) + rng.double(0...2)
            p.stamp(sprite, x: x, y: y, flipX: rng.bool())
        }
    }

    private func paintField(_ p: inout AsciiPainter, rng: inout PixelRandom) {
        let field = Color(px: style.field)
        let light = Color(px: style.fieldLight)
        p.fill(0, Double(horizonY), Double(cols), Double(SceneGeometry.rows - horizonY),
               glyph: ";", color: field)

        for _ in 0..<(cols / 3) {
            let x = Double(rng.int(0...(cols - 4)))
            let y = Double(rng.int((horizonY + 2)...(frontY - 1)))
            p.fill(x, y, Double(rng.int(2...4)), 1, glyph: "-", color: light)
        }

        if style.flowers {
            for _ in 0..<max(3, cols / 22) {
                let x = Double(rng.int(2...(cols - 5)))
                let y = Double(rng.int((horizonY + 4)...(frontY - 3)))
                p.stamp(PupSprites.flower, x: x, y: y)
            }
        }
    }

    private func paintDogShadow(_ p: inout AsciiPainter) {
        guard layout.dogAction != .sleep else { return }
        let width = Double(dogSprite.width) * dogScale
        let inset = layout.dogAction == .jump ? 9.0 : 5.0
        p.fill(dogX + inset, Double(feetY - 1),
               width - inset * 2, 2, glyph: "_", color: Color(px: style.shadow))
    }

    // MARK: Dog

    private var dogSprite: PixelSprite {
        switch layout.dogAction {
        case .sit: PupSprites.dogSit
        case .trot: PupSprites.dogTrot
        case .sniff: PupSprites.dogSniff
        case .jump: PupSprites.dogJump
        case .sleep: PupSprites.dogSleep
        }
    }

    private var dogX: Double {
        let width = Double(dogSprite.width) * dogScale
        let reservedCols = Double(reservedTrailingWidth) / Double(max(cellW, 0.5))
        let usable = max(Double(cols) - width - 12 - reservedCols, 1)
        return 6 + layout.dogUnit * usable
    }

    private func paintDog(_ p: inout AsciiPainter) {
        let sprite = dogSprite
        let width = Double(sprite.width) * dogScale
        let height = Double(sprite.height) * dogScale
        // Same hover as the pixel dog.
        let lift = 9.0
        let originY = Double(feetY) - height - lift
        p.stamp(sprite, x: dogX, y: originY, flipX: layout.dogFacesLeft, scale: dogScale)

        if layout.dogAction == .sleep {
            p.stamp(PupSprites.zzz,
                    x: dogX + (layout.dogFacesLeft ? -7 : width - 1),
                    y: originY - 8,
                    glyphs: .grid)
        }
        if style.butterflies {
            var rng = PixelRandom(seed: layout.flutterSeed)
            let wings = [PupSprites.butterflyBlue, PupSprites.butterflyYellow, PupSprites.butterflyOrange]
            let dir: Double = layout.dogFacesLeft ? -1 : 1
            let nose = layout.dogFacesLeft ? 0.0 : width
            let spots = [
                (nose + dir * 5, 0.0),
                (nose + dir * 13, -7.0),
                (nose - dir * (width * 0.4), -12.0),
            ]
            for (i, spot) in spots.enumerated() {
                p.stamp(wings[i % wings.count],
                        x: dogX + spot.0 + rng.double(-3...3) - 3,
                        y: originY + spot.1 + rng.double(-3...3),
                        flipX: rng.bool())
            }
        }
    }

    // MARK: Foreground

    private func paintFrontGrass(_ p: inout AsciiPainter, rng: inout PixelRandom) {
        let front = Color(px: style.front)
        let blade = Color(px: style.frontBlade)
        p.fill(0, Double(frontY), Double(cols), Double(SceneGeometry.rows - frontY),
               glyph: "\"", color: front)

        var x = 0
        while x < cols {
            let h = Double(rng.int(2...5))
            p.fill(Double(x), Double(frontY) - h, 1, h, glyph: "\"", color: front)
            if rng.bool(0.5) {
                p.fill(Double(x) + 1, Double(frontY) - max(h - 1, 1), 1, max(h - 1, 1),
                       glyph: "'", color: blade)
            }
            x += rng.int(2...3)
        }
        for _ in 0..<(cols / 3) {
            let bx = Double(rng.int(0...(cols - 1)))
            let by = Double(rng.int((frontY + 1)...(SceneGeometry.rows - 2)))
            p.fill(bx, by, 1, 2, glyph: "'", color: blade)
        }
    }

    private func paintRain(_ p: inout AsciiPainter, rng: inout PixelRandom) {
        let colors = [Color(px: style.rainA), Color(px: style.rainB)]
        for _ in 0..<(cols * SceneGeometry.rows / 115) {
            let x = Double(rng.int(1...(cols - 1)))
            let y = Double(rng.int(0...(SceneGeometry.rows - 6)))
            let c = rng.pick(colors)
            p.put(x, y, glyph: "/", color: c)
            p.put(x - 1, y + 3, glyph: "/", color: c)
        }
    }

    private func paintSnow(_ p: inout AsciiPainter, rng: inout PixelRandom) {
        for _ in 0..<(cols * SceneGeometry.rows / 110) {
            let x = Double(rng.int(0...(cols - 2)))
            let y = Double(rng.int(0...(SceneGeometry.rows - 4)))
            if rng.bool(0.25) {
                p.put(x, y, glyph: "*", color: .white)
            } else {
                p.put(x, y, glyph: ".", color: .white)
            }
        }
    }

    private func paintFog(_ p: inout AsciiPainter, rng: inout PixelRandom) {
        for band in 0..<4 {
            let y = 16.0 + Double(band) * 11 + rng.double(-2...2)
            let mist = Color.white.opacity(band % 2 == 0 ? 0.42 : 0.30)
            var x = -rng.double(0...10)
            while x < Double(cols) {
                let w = rng.double(14...34)
                p.fill(x, y + rng.double(-1...1), w, rng.double(3...5), glyph: "~", color: mist)
                x += w + rng.double(2...8)
            }
        }
    }
}

/// The ASCII counterpart of the pixel `ZStack` in `PupSceneView`: ~30 rows
/// of run-colored monospaced text on a terminal-dark backdrop. Each row is a
/// single `Text`, so the whole scene stays well inside the Live Activity
/// view budget.
struct AsciiSceneRenderer: View {
    let scene: PupScene
    let layout: SceneLayout
    var minHeight: CGFloat = 120
    var reservedTrailingWidth: CGFloat = 0

    /// Terminal-dark backdrop that makes the colored glyphs pop.
    static let backdrop = Color(px: 0x10141A)

    var body: some View {
        GeometryReader { proxy in
            let composer = AsciiSceneComposer(scene: scene,
                                              layout: layout,
                                              width: max(proxy.size.width, minHeight),
                                              height: minHeight,
                                              reservedTrailingWidth: reservedTrailingWidth)
            let rows = composer.rowStrings()
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows.indices, id: \.self) { i in
                    Text(rows[i])
                        .font(.system(size: composer.fontSize, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(height: composer.cellH, alignment: .leading)
                }
            }
            .frame(width: proxy.size.width, height: minHeight, alignment: .topLeading)
            .background(Self.backdrop)
            .clipped()
        }
    }
}
