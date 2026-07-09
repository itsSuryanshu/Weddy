import SwiftUI

/// The ASCII analog of `PixelPainter`: a character-cell buffer instead of
/// merged vector paths. Callers keep working in the same 60-row virtual
/// pixel space as the pixel composer; one character cell covers 1 pixel
/// horizontally and 2 pixels vertically (monospaced glyphs are ~1:2), so the
/// buffer is 30 character rows tall and shares the pixel grid's column count.
struct AsciiPainter {
    struct Cell: Equatable {
        var glyph: Character
        var color: Color
    }

    /// Pixel rows per character cell (vertical downsample factor).
    static let pxPerRow = 2
    /// Glyphs ordered by ink coverage; luminance picks one, so brighter
    /// sprite colors read as denser terminal characters.
    static let ramp: [Character] = Array(" .:-=+*#%@")
    /// Sprites never drop below this ramp density — a dark outline drawn as
    /// a lone "." would dissolve; clamping keeps silhouettes solid while the
    /// color still carries the shading.
    static let spriteRampFloor = 4

    let cols: Int
    let rows: Int
    private var buffer: [Cell?]

    /// `cols` in character columns (== pixel columns), `pxRows` in virtual
    /// pixels (60 for a full scene).
    init(cols: Int, pxRows: Int) {
        self.cols = max(cols, 1)
        self.rows = (pxRows + Self.pxPerRow - 1) / Self.pxPerRow
        self.buffer = Array(repeating: nil, count: self.cols * rows)
    }

    static func luminance(_ hex: UInt32) -> Double {
        let r = Double((hex >> 16) & 0xFF)
        let g = Double((hex >> 8) & 0xFF)
        let b = Double(hex & 0xFF)
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
    }

    /// Ramp glyph for a color, optionally clamped to a minimum density.
    static func glyph(for hex: UInt32, floor minIndex: Int = 0) -> Character {
        let index = Int(luminance(hex) * Double(ramp.count - 1) + 0.5)
        return ramp[min(max(index, minIndex), ramp.count - 1)]
    }

    /// Writes one cell addressed in virtual pixel coordinates. Later writes
    /// overwrite earlier ones (painter's algorithm on a buffer).
    mutating func put(_ x: Double, _ y: Double, glyph: Character, color: Color) {
        let col = Int(x.rounded(.down))
        let row = Int(y.rounded(.down)) / Self.pxPerRow
        guard col >= 0, col < cols, row >= 0, row < rows else { return }
        buffer[row * cols + col] = Cell(glyph: glyph, color: color)
    }

    /// Fills a rect given in virtual pixel coordinates.
    mutating func fill(_ x: Double, _ y: Double, _ w: Double, _ h: Double,
                       glyph: Character, color: Color) {
        guard w > 0, h > 0 else { return }
        let x0 = Int(x.rounded(.down)), x1 = Int((x + w).rounded(.up))
        let y0 = Int(y.rounded(.down)), y1 = Int((y + h).rounded(.up))
        for py in stride(from: y0, to: y1, by: 1) {
            for px in stride(from: x0, to: x1, by: 1) {
                put(Double(px), Double(py), glyph: glyph, color: color)
            }
        }
    }

    /// How `stamp` picks the character for a sprite cell.
    enum GlyphMode {
        /// Density ramp indexed by the cell color's luminance.
        case ramp
        /// The sprite grid's own character (for grids that are already
        /// legible ASCII, like the "z" of the sleep bubble).
        case grid
    }

    /// Stamps a sprite with its top-left corner at (x, y) in virtual pixels,
    /// nearest-neighbor sampling the grid. Two pixel rows land on each
    /// character row; iterating them top-down means the lower row wins,
    /// which keeps outlines and feet solid.
    mutating func stamp(_ sprite: PixelSprite, x: Double, y: Double,
                        flipX: Bool = false, scale: Double = 1,
                        glyphs: GlyphMode = .ramp) {
        let outW = Int((Double(sprite.width) * scale).rounded(.up))
        let outH = Int((Double(sprite.height) * scale).rounded(.up))
        for oy in 0..<outH {
            let sy = min(Int(Double(oy) / scale), sprite.height - 1)
            let rowChars = sprite.grid[sy]
            for ox in 0..<outW {
                var sx = min(Int(Double(ox) / scale), sprite.width - 1)
                if flipX { sx = sprite.width - 1 - sx }
                guard sx < rowChars.count else { continue }
                let ch = rowChars[sx]
                guard ch != ".", let hex = sprite.palette[ch] else { continue }
                let glyph = switch glyphs {
                case .ramp: Self.glyph(for: hex, floor: Self.spriteRampFloor)
                case .grid: ch
                }
                put(x + Double(ox), y + Double(oy), glyph: glyph, color: Color(px: hex))
            }
        }
    }

    /// One `AttributedString` per character row, merging horizontal runs of
    /// equal color so each row stays a handful of attribute runs. Empty
    /// cells become spaces (the renderer's backdrop shows through).
    func rowStrings() -> [AttributedString] {
        var result: [AttributedString] = []
        result.reserveCapacity(rows)
        for row in 0..<rows {
            var line = AttributedString()
            var runText = ""
            var runColor: Color?
            func flush() {
                guard !runText.isEmpty else { return }
                var piece = AttributedString(runText)
                piece.foregroundColor = runColor
                line += piece
                runText = ""
            }
            for col in 0..<cols {
                if let cell = buffer[row * cols + col] {
                    if runColor != cell.color {
                        flush()
                        runColor = cell.color
                    }
                    runText.append(cell.glyph)
                } else {
                    if runColor != nil {
                        flush()
                        runColor = nil
                    }
                    runText.append(" ")
                }
            }
            flush()
            result.append(line)
        }
        return result
    }
}
