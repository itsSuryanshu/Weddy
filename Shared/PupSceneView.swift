import SwiftUI

/// Renders a weather scene entirely from code-drawn pixel models — no images,
/// no fonts. Everything rasterizes into a handful of vector `Path`s, which is
/// the one rendering primitive Live Activities support without restriction.
///
/// The static world (sky, sun/moon, clouds, hills, trees, grass, weather) is
/// deterministic from `layout.worldSeed`; the dog is its own view offset by
/// `layout.dogUnit`, so a content-state update slides it to a new spot.
struct PupSceneView: View {
    let scene: PupScene
    let layout: SceneLayout
    /// Live Activity lock-screen views must declare an explicit size;
    /// GeometryReader alone often collapses to zero there.
    var minHeight: CGFloat = 120

    var body: some View {
        GeometryReader { proxy in
            let composer = SceneComposer(scene: scene,
                                         layout: layout,
                                         width: max(proxy.size.width, minHeight),
                                         height: minHeight)
            let dog = composer.dogGroup()
            ZStack(alignment: .topLeading) {
                PixelPaintingView(layers: composer.backgroundLayers())
                PixelPaintingView(layers: dog.layers)
                    .offset(x: dog.origin.x, y: dog.origin.y)
                PixelPaintingView(layers: composer.foregroundLayers())
            }
            .frame(width: proxy.size.width, height: minHeight, alignment: .topLeading)
            .clipped()
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, idealHeight: minHeight, maxHeight: minHeight)
        .animation(.smooth(duration: 1.6), value: layout)
    }
}

// MARK: - Composer

/// Builds the draw lists for one scene at one size. All randomness is seeded,
/// so the app and the widget extension paint identical pixels.
struct SceneComposer {
    let scene: PupScene
    let layout: SceneLayout
    let pixel: CGFloat
    let cols: Int

    /// Art grid height in pixels; width adapts to the view.
    static let rows = 60
    /// Where the hills meet the field.
    private let horizonY = 34
    /// Top of the foreground grass band.
    private let frontY = 52
    /// Where the dog's paws rest (slightly inside the front grass for depth).
    private let feetY = 55
    /// The dog is the hero — chunkier pixels than the scenery, like the
    /// reference art where the pup dominates the frame.
    private let dogScale = 1.5

    private let style: SceneStyle

    init(scene: PupScene, layout: SceneLayout, width: CGFloat, height: CGFloat) {
        self.scene = scene
        self.layout = layout
        self.pixel = height / CGFloat(Self.rows)
        self.cols = Int((width / max(pixel, 0.5)).rounded(.up))
        self.style = SceneStyle.for(scene)
    }

    // MARK: Background (sky → celestial → clouds → hills → trees → field)

    func backgroundLayers() -> [(color: Color, path: Path)] {
        var p = PixelPainter(pixel: pixel)
        var rng = PixelRandom(seed: layout.worldSeed)

        paintSky(&p)
        if style.showsStars { paintStars(&p, rng: &rng) }
        if style.showsSun { p.stamp(PupSprites.sun, x: Double(cols - 20), y: 2) }
        if style.showsMoon { p.stamp(PupSprites.moon, x: Double(cols - 17), y: 4) }
        paintClouds(&p, rng: &rng)
        paintHills(&p, rng: &rng)
        paintField(&p, rng: &rng)
        paintDogShadow(&p)
        return p.layers
    }

    private func paintSky(_ p: inout PixelPainter) {
        let bands = 6
        let bandHeight = Double(Self.rows) / Double(bands)
        for i in 0..<bands {
            let t = Double(i) / Double(bands - 1)
            let color = Color(px: lerpHex(scene.skyTopHex, scene.skyBottomHex, t))
            p.rect(0, Double(i) * bandHeight, Double(cols), bandHeight + 0.5, color)
        }
    }

    private func paintStars(_ p: inout PixelPainter, rng: inout PixelRandom) {
        let palette: [UInt32] = [0xFFFFFF, 0xBFD4FF, 0xFFE9A8]
        for _ in 0..<(cols / 4) {
            let x = Double(rng.int(0...(cols - 1)))
            let y = Double(rng.int(0...(horizonY - 8)))
            let color = Color(px: rng.pick(palette))
            if rng.bool(0.2) {
                // Twinkle: a little plus shape.
                p.dot(x, y, color)
                p.dot(x - 1, y, color)
                p.dot(x + 1, y, color)
                p.dot(x, y - 1, color)
                p.dot(x, y + 1, color)
            } else {
                p.dot(x, y, color)
            }
        }
    }

    private func paintClouds(_ p: inout PixelPainter, rng: inout PixelRandom) {
        guard style.cloudCount > 0 else { return }
        let sprite = style.stormClouds ? PupSprites.stormCloud : PupSprites.cloud
        let small = style.stormClouds ? PupSprites.stormCloud : PupSprites.cloudSmall
        // Keep clouds away from the sun's corner on clear days.
        let maxX = style.showsSun ? Double(cols) * 0.62 : Double(cols - 24)
        let slot = max(maxX / Double(style.cloudCount), 26)
        for i in 0..<style.cloudCount {
            let big = rng.bool(0.55)
            let x = Double(i) * slot + rng.double(0...(slot * 0.45))
            let y = rng.double(1...11)
            p.stamp(big ? sprite : small, x: x, y: y)
        }
    }

    private func paintHills(_ p: inout PixelPainter, rng: inout PixelRandom) {
        let phase1 = rng.double(0...6.28)
        let phase2 = rng.double(0...6.28)
        let far = Color(px: style.farHill)
        let near = Color(px: style.hill)
        let edge = Color(px: style.hillEdge)

        for x in 0..<cols {
            let fx = Double(x)
            let farTop = 27.0 + (3.2 * sin(fx * 0.045 + phase1)).rounded()
            p.rect(fx, farTop, 1, Double(horizonY) - farTop + 1, far)
        }
        for x in 0..<cols {
            let fx = Double(x)
            let top = 31.0 + (2.0 * sin(fx * 0.09 + phase2) + 1.2 * sin(fx * 0.031 + phase1)).rounded()
            p.rect(fx, top, 1, 1, edge)
            p.rect(fx, top + 1, 1, Double(horizonY) - top, near)
        }

        // Trees stand on the near hill line.
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

    private func paintField(_ p: inout PixelPainter, rng: inout PixelRandom) {
        let field = Color(px: style.field)
        let light = Color(px: style.fieldLight)
        p.rect(0, Double(horizonY), Double(cols), Double(Self.rows - horizonY), field)

        // Mown-grass texture: short light dashes.
        for _ in 0..<(cols / 3) {
            let x = Double(rng.int(0...(cols - 4)))
            let y = Double(rng.int((horizonY + 2)...(frontY - 1)))
            p.rect(x, y, Double(rng.int(2...4)), 1, light)
        }

        if style.flowers {
            for _ in 0..<max(3, cols / 22) {
                let x = Double(rng.int(2...(cols - 5)))
                let y = Double(rng.int((horizonY + 4)...(frontY - 3)))
                p.stamp(PupSprites.flower, x: x, y: y)
            }
        }
    }

    private func paintDogShadow(_ p: inout PixelPainter) {
        guard layout.dogAction != .sleep else { return }
        let width = Double(dogSprite.width) * dogScale
        let inset = layout.dogAction == .jump ? 9.0 : 5.0
        p.rect(dogX + inset, Double(feetY - 1),
               width - inset * 2, 2, Color(px: style.shadow))
    }

    // MARK: Dog (own group so position changes can slide)

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
        let usable = max(Double(cols) - width - 12, 1)
        return 6 + layout.dogUnit * usable
    }

    func dogGroup() -> (layers: [(color: Color, path: Path)], origin: CGPoint) {
        var p = PixelPainter(pixel: pixel)
        let sprite = dogSprite
        let width = Double(sprite.width) * dogScale
        let height = Double(sprite.height) * dogScale
        let lift = layout.dogAction == .jump ? 9.0 : 0.0
        p.stamp(sprite, x: 0, y: 0, flipX: layout.dogFacesLeft, scale: dogScale)

        if layout.dogAction == .sleep {
            p.stamp(PupSprites.zzz,
                    x: layout.dogFacesLeft ? -7 : width - 1,
                    y: -8)
        }
        if style.butterflies {
            var rng = PixelRandom(seed: layout.worldSeed ^ 0xB077E7F1)
            let wings = [PupSprites.butterflyBlue, PupSprites.butterflyYellow, PupSprites.butterflyOrange]
            let spots = [(-9.0, 6.0), (width + 2, 0.0), (width - 12, -7.0)]
            for (i, spot) in spots.enumerated() {
                p.stamp(wings[i % wings.count],
                        x: spot.0 + rng.double(-2...2),
                        y: spot.1 + rng.double(-2...2),
                        flipX: rng.bool())
            }
        }

        let originY = Double(feetY) - height - lift
        return (p.layers, CGPoint(x: dogX * pixel, y: originY * pixel))
    }

    // MARK: Foreground (front grass → weather overlays)

    func foregroundLayers() -> [(color: Color, path: Path)] {
        var p = PixelPainter(pixel: pixel)
        var rng = PixelRandom(seed: layout.worldSeed ^ 0xF06E6006)

        paintFrontGrass(&p, rng: &rng)
        if style.rain { paintRain(&p, rng: &rng) }
        if style.snow { paintSnow(&p, rng: &rng) }
        if style.lightning {
            let x = rng.double(12...(Double(cols) * 0.5))
            p.stamp(PupSprites.lightning, x: x, y: 13, scale: 1.5)
        }
        if style.fogBands { paintFog(&p, rng: &rng) }
        return p.layers
    }

    private func paintFrontGrass(_ p: inout PixelPainter, rng: inout PixelRandom) {
        let front = Color(px: style.front)
        let blade = Color(px: style.frontBlade)
        p.rect(0, Double(frontY), Double(cols), Double(Self.rows - frontY), front)

        var x = 0
        while x < cols {
            let h = Double(rng.int(2...5))
            p.rect(Double(x), Double(frontY) - h, 1, h, front)
            if rng.bool(0.5) {
                p.rect(Double(x) + 1, Double(frontY) - max(h - 1, 1), 1, max(h - 1, 1), blade)
            }
            x += rng.int(2...3)
        }
        // Blade highlights inside the band.
        for _ in 0..<(cols / 3) {
            let bx = Double(rng.int(0...(cols - 1)))
            let by = Double(rng.int((frontY + 1)...(Self.rows - 2)))
            p.rect(bx, by, 1, 2, blade)
        }
    }

    private func paintRain(_ p: inout PixelPainter, rng: inout PixelRandom) {
        let colors = [Color(px: style.rainA), Color(px: style.rainB)]
        for _ in 0..<(cols * Self.rows / 115) {
            let x = Double(rng.int(1...(cols - 1)))
            let y = Double(rng.int(0...(Self.rows - 6)))
            let c = rng.pick(colors)
            p.rect(x, y, 1, 3, c)
            p.rect(x - 1, y + 3, 1, 2, c)
        }
    }

    private func paintSnow(_ p: inout PixelPainter, rng: inout PixelRandom) {
        for _ in 0..<(cols * Self.rows / 110) {
            let x = Double(rng.int(0...(cols - 2)))
            let y = Double(rng.int(0...(Self.rows - 4)))
            if rng.bool(0.25) {
                p.rect(x, y, 2, 2, .white)
            } else {
                p.dot(x, y, .white)
            }
        }
    }

    private func paintFog(_ p: inout PixelPainter, rng: inout PixelRandom) {
        for band in 0..<4 {
            let y = 16.0 + Double(band) * 11 + rng.double(-2...2)
            let mist = Color.white.opacity(band % 2 == 0 ? 0.42 : 0.30)
            var x = -rng.double(0...10)
            while x < Double(cols) {
                let w = rng.double(14...34)
                p.rect(x, y + rng.double(-1...1), w, rng.double(3...5), mist)
                x += w + rng.double(2...8)
            }
        }
    }
}

// MARK: - Per-scene styling

private struct SceneStyle {
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

    static func `for`(_ scene: PupScene) -> SceneStyle {
        switch scene {
        case .clearDay:
            SceneStyle(farHill: 0x63C96B, hill: 0x3FA34D, hillEdge: 0x2C7A3B,
                       field: 0x6FD44E, fieldLight: 0x8CE06B,
                       front: 0x2F9E44, frontBlade: 0x54C05A, shadow: 0x3E9E3F,
                       showsSun: true, cloudCount: 2, flowers: true)
        case .warmDay:
            SceneStyle(farHill: 0x63C96B, hill: 0x3FA34D, hillEdge: 0x2C7A3B,
                       field: 0x6FD44E, fieldLight: 0x8CE06B,
                       front: 0x2F9E44, frontBlade: 0x54C05A, shadow: 0x3E9E3F,
                       showsSun: true, cloudCount: 2, butterflies: true, flowers: true)
        case .cloudy:
            SceneStyle(farHill: 0x57AE63, hill: 0x389447, hillEdge: 0x27703A,
                       field: 0x63C24C, fieldLight: 0x7CD063,
                       front: 0x2A8E3E, frontBlade: 0x4AAE52, shadow: 0x358E38,
                       cloudCount: 5, flowers: true)
        case .rain:
            SceneStyle(farHill: 0x2E7A44, hill: 0x255F36, hillEdge: 0x1B4A29,
                       field: 0x3C9145, fieldLight: 0x4EA455,
                       front: 0x1E6B33, frontBlade: 0x2F8442, shadow: 0x1E6B33,
                       cloudCount: 3, stormClouds: true, darkTrees: true, rain: true)
        case .thunder:
            SceneStyle(farHill: 0x235B37, hill: 0x1A4A2C, hillEdge: 0x123B21,
                       field: 0x2C7038, fieldLight: 0x357E42,
                       front: 0x143F22, frontBlade: 0x1F5A31, shadow: 0x143F22,
                       rainA: 0x9DB8D9, rainB: 0x7A97BD,
                       cloudCount: 3, stormClouds: true, darkTrees: true,
                       rain: true, lightning: true)
        case .snow:
            SceneStyle(farHill: 0xCFE6F7, hill: 0xBFDCF2, hillEdge: 0x9CC4E4,
                       field: 0xF2FAFF, fieldLight: 0xFFFFFF,
                       front: 0xD6EBFA, frontBlade: 0xEAF6FF, shadow: 0xBFDCF2,
                       cloudCount: 3, snow: true)
        case .fog:
            SceneStyle(farHill: 0x7FA98B, hill: 0x6A9678, hillEdge: 0x557F63,
                       field: 0x86B292, fieldLight: 0x97C2A2,
                       front: 0x5E8A6C, frontBlade: 0x74A181, shadow: 0x5E8A6C,
                       fogBands: true)
        case .night:
            SceneStyle(farHill: 0x1C5B34, hill: 0x144A28, hillEdge: 0x0E3A1F,
                       field: 0x1F6B38, fieldLight: 0x2A7C44,
                       front: 0x0F4423, frontBlade: 0x1B5C31, shadow: 0x0F4423,
                       showsMoon: true, showsStars: true, darkTrees: true)
        }
    }
}

private func lerpHex(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
    func mix(_ shift: UInt32) -> UInt32 {
        let ca = Double((a >> shift) & 0xFF)
        let cb = Double((b >> shift) & 0xFF)
        return UInt32((ca + (cb - ca) * t).rounded()) << shift
    }
    return mix(16) | mix(8) | mix(0)
}

#if !RENDER_TOOL
#Preview("Scenes", traits: .fixedLayout(width: 380, height: 1100)) {
    ScrollView {
        VStack(spacing: 8) {
            ForEach(PupScene.allCases, id: \.self) { scene in
                PupSceneView(scene: scene, layout: .preview(for: scene))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
}
#endif
