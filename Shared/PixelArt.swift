import SwiftUI

// MARK: - Deterministic RNG

/// SplitMix64 — tiny deterministic generator so the app and the widget
/// extension render the exact same scene for a given seed.
struct PixelRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform Double in [0, 1).
    mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    mutating func int(_ range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(unit() * Double(range.count))
    }

    mutating func double(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }

    mutating func bool(_ probability: Double = 0.5) -> Bool {
        unit() < probability
    }

    mutating func pick<T>(_ options: [T]) -> T {
        options[min(int(0...(options.count - 1)), options.count - 1)]
    }
}

// MARK: - Sprite model

/// A pixel sprite "model": rows of palette characters. `.` is transparent.
/// Sprites are data, not images — they rasterize into vector `Path`s at any
/// pixel size, which is what lets them render inside a Live Activity.
struct PixelSprite {
    let grid: [[Character]]
    let palette: [Character: Color]
    let width: Int
    let height: Int

    init(palette: [Character: Color], _ rows: [String]) {
        self.init(palette: palette, grid: rows.map(Array.init))
    }

    init(palette: [Character: Color], grid: [[Character]]) {
        self.grid = grid
        self.palette = palette
        self.width = grid.map(\.count).max() ?? 0
        self.height = grid.count
    }

    /// Same shape, different colors (e.g. trees at night).
    func repainted(with palette: [Character: Color]) -> PixelSprite {
        PixelSprite(palette: palette, grid: grid)
    }
}

// MARK: - Painter

/// Accumulates colored pixel rects and merges them into one `Path` per color.
/// Rendering a whole layer of the scene (all trees, all raindrops, the dog…)
/// this way keeps the Live Activity view tree tiny: a handful of filled
/// shapes instead of thousands of views.
struct PixelPainter {
    /// Ordered draw list. Later entries paint over earlier ones.
    private(set) var layers: [(color: Color, path: Path)] = []
    private var index: [Color: Int] = [:]
    /// Size in points of one art pixel.
    let pixel: CGFloat
    /// Tiny overlap that hides antialiasing seams between adjacent colors.
    private var bleed: CGFloat { pixel * 0.06 }

    init(pixel: CGFloat) {
        self.pixel = pixel
    }

    /// Fills a rect given in art-pixel coordinates.
    mutating func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: Color) {
        guard w > 0, h > 0 else { return }
        let r = CGRect(x: CGFloat(x) * pixel - bleed,
                       y: CGFloat(y) * pixel - bleed,
                       width: CGFloat(w) * pixel + bleed * 2,
                       height: CGFloat(h) * pixel + bleed * 2)
        if let i = index[color] {
            layers[i].path.addRect(r)
        } else {
            index[color] = layers.count
            var p = Path()
            p.addRect(r)
            layers.append((color, p))
        }
    }

    mutating func dot(_ x: Double, _ y: Double, _ color: Color) {
        rect(x, y, 1, 1, color)
    }

    /// Stamps a sprite with its top-left corner at (x, y) in art pixels,
    /// merging horizontal runs of equal color into single rects.
    mutating func stamp(_ sprite: PixelSprite, x: Double, y: Double,
                        flipX: Bool = false, scale: Double = 1) {
        for (row, chars) in sprite.grid.enumerated() {
            var col = 0
            while col < chars.count {
                let ch = chars[col]
                guard let color = sprite.palette[ch], ch != "." else {
                    col += 1
                    continue
                }
                var run = 1
                while col + run < chars.count && chars[col + run] == ch {
                    run += 1
                }
                let px = flipX ? Double(sprite.width - col - run) : Double(col)
                rect(x + px * scale, y + Double(row) * scale,
                     Double(run) * scale, scale, color)
                col += run
            }
        }
    }
}

/// Renders a painter's draw list. One `fill` per color in paint order.
struct PixelPaintingView: View {
    let layers: [(color: Color, path: Path)]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(layers.enumerated()), id: \.offset) { _, layer in
                layer.path.fill(layer.color, style: FillStyle(antialiased: false))
            }
        }
    }
}
