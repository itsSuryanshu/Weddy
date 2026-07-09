import SwiftUI

extension Color {
    /// 0xRRGGBB convenience for the pixel palettes.
    init(px hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// All pixel sprites in the scene. Rows use per-sprite palettes; `.` is
/// transparent. Edit the grids to edit the art — nothing is baked. Preview
/// any change with `tools/render_scenes.swift`.
enum PupSprites {

    // MARK: Dog palette

    private static let dogPalette: [Character: UInt32] = [
        "k": 0x8A4715,  // outline
        "o": 0xF59B3D,  // coat
        "O": 0xFFBE6B,  // coat highlight
        "d": 0xD9772A,  // coat shade / ears
        "c": 0xFFDCA3,  // muzzle cream
        "n": 0x2B1608,  // nose
        "e": 0x1E1006,  // eyes
        "t": 0xFF6FA0,  // tongue
        "b": 0x4B7BEC,  // bandana
        "B": 0x2F55B8,  // bandana shade
    ]

    // MARK: Dog poses

    /// Front-facing happy sit (like the reference art).
    static let dogSit = PixelSprite(palette: dogPalette, [
        "......kkkkkkkk......",
        ".....koooooooOk.....",
        "...kkooooooooOOkk...",
        "..kdkooooooooookdk..",
        "..kdkooooooooookdk..",
        "..kdkooeooooeookdk..",
        "..kdkoooccccoookdk..",
        "..kkkooccnnccookkk..",
        "....kocctttcccok....",
        ".....kccttttcck.....",
        "......kbbbbbbk......",
        ".....kbBbbbbBbk.....",
        "....kookBbbBkook....",
        "...kooookBBkoooook..",
        "..koooooooooooooook.",
        ".kooOoooooooooOook..",
        ".kdoookookookoodk...",
        ".kdoookookookoodk...",
        "..kdokoookoookodk...",
        "...kkkoookoookkk....",
        "......kkk..kkk......",
    ])

    /// Side-view trot, drawn facing right.
    static let dogTrot = PixelSprite(palette: dogPalette, [
        "..........................",
        "kk................kkkkk...",
        "kOk..............kooooOk..",
        "koOk............kddoooook.",
        ".koOkkkkkkkkkkkkkddoeoook.",
        ".koooooooooooooooddooookk.",
        "..koooooooooooooobooccnnk.",
        "..kOooooooooooooobbkcccck.",
        ".koooooooooooooookbbkttk..",
        ".koooooooooooooookkbkkk...",
        ".kooooooooooooooook.......",
        "..kddoooooooooddok........",
        "..kokdooooooodkok.........",
        "..kdk.kok.kdk.kok.........",
        "..kdk.kok.kdk.kok.........",
        ".kdok.kdok.kdok.kdok......",
        ".kkk..kkk..kkk..kkk.......",
    ])

    /// Side-view jump, drawn facing right — legs stretched, tail up.
    static let dogJump = PixelSprite(palette: dogPalette, [
        "kk..................kkkkk...",
        "kOkk...............koooook..",
        "koOOk.............kddoooOOk.",
        ".kooOk...........kddoeooook.",
        "..koookkkkkkkkkkkoooooooook.",
        "...kooooooooooooooooooccnnk.",
        "...kOoooooooooooooobkcccck..",
        "..koooooooooooooookbbkttk...",
        ".kooooooooooooooookkbkk.....",
        "kooookoooooooookook.........",
        "koook.kdok.kdok.koook.......",
        "kook..kok..kok..koook.......",
        ".kk....k....k...kook........",
        ".................kk.........",
    ])

    /// Side-view sniffing, nose down in the grass, drawn facing right.
    static let dogSniff = PixelSprite(palette: dogPalette, [
        ".kk.......................",
        "koOk......................",
        "koOok.....................",
        ".kookkkkkkkkkkkkk.........",
        "..koooooooooooooook.......",
        "..kooooooooooooooook......",
        "..kOooooooooooooooook.....",
        "..koooooooooooookddook....",
        "..kooooooooooookkodook....",
        "..kddoooooooodok.koooook..",
        "..kokdooooooodkk.kboeoook.",
        "..kok.kok.kok.kokkbkoccnk.",
        ".kdok.kok.kok.kdokkk.kcnk.",
        ".kkk.kkk.kkk.kkk.....kkk..",
    ])

    /// Curled up asleep.
    static let dogSleep = PixelSprite(palette: dogPalette, [
        "......kkkkkkkk........",
        "....kkoooooooOkk......",
        "...koooooooooOOOk.....",
        "..koooooooooooooOk....",
        ".kdkkoooccccooook.....",
        "kddkoooccccoooooOk...",
        "kdkooeeooeeoooooook..",
        "kokooccccccccddddooook",
        ".kkoocnnncoodkkkkdook.",
        "..kkkkkkkkkk....kkkk..",
    ])

    // MARK: Scenery

    private static let treePalette: [Character: UInt32] = [
        "k": 0x1C5A2B,  // canopy outline
        "g": 0x3FA34D,  // canopy
        "G": 0x7DD181,  // canopy highlight
        "s": 0x2C7A3B,  // canopy shade
        "t": 0x7A4A21,  // trunk
        "T": 0x5C3317,  // trunk shade
    ]

    static let tree = PixelSprite(palette: treePalette, [
        "....kkkkkk....",
        "..kkgggGGgkk..",
        ".kgggggGGGggk.",
        "kgggggggGGgggk",
        "kgsggggggggggk",
        "kssgggggggGggk",
        "kssggggggggggk",
        ".kssgggggggsk.",
        "..kssgggggsk..",
        "...kkssgskk...",
        ".....ktTk.....",
        ".....ktTk.....",
        "....kttTTk....",
    ])

    static let treeSmall = PixelSprite(palette: treePalette, [
        "..kkkkk..",
        ".kggGGgk.",
        "kggggGggk",
        "ksggggggk",
        ".ksggggk.",
        "..kssgk..",
        "...ktk...",
        "...ktk...",
    ])

    /// Muted canopy for night / storm scenes.
    private static let treeNightPalette: [Character: UInt32] = [
        "k": 0x0C2E16,
        "g": 0x1E5B33,
        "G": 0x2F7A45,
        "s": 0x164426,
        "t": 0x3A2410,
        "T": 0x2A1A0B,
    ]

    static let treeNight = tree.repainted(with: treeNightPalette)
    static let treeSmallNight = treeSmall.repainted(with: treeNightPalette)

    /// Sleepy Zzz for the night scene.
    private static let zzzPalette: [Character: UInt32] = [
        "z": 0xCFE0FF
    ]

    static let zzz = PixelSprite(palette: zzzPalette, [
        "....zzzz",
        "......z.",
        ".....z..",
        "....zzzz",
        "zzz.....",
        "..z.....",
        ".z......",
        "zzz.....",
    ])

    private static let cloudPalette: [Character: UInt32] = [
        "w": 0xFFFFFF,
        "s": 0xD8ECFA,  // soft blue underside
    ]

    static let cloud = PixelSprite(palette: cloudPalette, [
        "......wwwww..........",
        "....wwwwwwwww..www...",
        "..wwwwwwwwwwwwwwwww..",
        ".wwwwwwwwwwwwwwwwwww.",
        "wwwwwwwwwwwwwwwwwwwww",
        "wsswwwwwwwwwwwwwwssww",
        ".sswsswwwwwwwssswwss.",
        "...ssssssssssssss....",
    ])

    static let cloudSmall = PixelSprite(palette: cloudPalette, [
        "...wwwww....",
        ".wwwwwwwww..",
        "wwwwwwwwwwww",
        "wsswwwwwssww",
        ".ssssssssss.",
    ])

    /// Dark storm cloud for rain / thunder scenes.
    private static let stormPalette: [Character: UInt32] = [
        "w": 0x9DB2C7,
        "s": 0x6B8199,
    ]

    static let stormCloud = cloud.repainted(with: stormPalette)

    private static let sunPalette: [Character: UInt32] = [
        "y": 0xFFE066,  // core
        "Y": 0xFFF3B0,  // core highlight
        "r": 0xFFD23E,  // rays
    ]

    static let sun = PixelSprite(palette: sunPalette, [
        "......r.......",
        "..r...r...r...",
        "...r.yyyy.r...",
        "....yyYYyy....",
        "...yyYYYYyy...",
        "r..yYYYYYYy..r",
        "r.yyYYYYYYyy.r",
        "...yYYYYYYy...",
        "...yyYYYYyy...",
        "....yyYYyy....",
        "...r.yyyy.r...",
        "..r...r...r...",
        "......r.......",
    ])

    private static let moonPalette: [Character: UInt32] = [
        "m": 0xFFF6C9,
        "M": 0xE8D89A,  // craters
    ]

    static let moon = PixelSprite(palette: moonPalette, [
        "...mmmm...",
        ".mmmmmm...",
        "mmmMmm....",
        "mmmmm.....",
        "mmMmm.....",
        "mmmmm.....",
        "mmmmmm....",
        ".mmmmmmm..",
        "...mmmmmm.",
    ])

    private static func butterflyPalette(_ wing: UInt32, _ shade: UInt32) -> [Character: UInt32] {
        [
            "w": wing,
            "W": 0xFFFFFF,  // wing spot
            "s": shade,
            "b": 0x2B1608,  // body
        ]
    }

    private static let butterflyGrid = [
        "ww..ww",
        "wWbbWw",
        "swbbws",
        ".sbbs.",
    ]

    static let butterflyBlue = PixelSprite(
        palette: butterflyPalette(0x59C3F2, 0x2E86D9), butterflyGrid)

    static let butterflyYellow = PixelSprite(
        palette: butterflyPalette(0xFFD23E, 0xF2A03D), butterflyGrid)

    static let butterflyOrange = PixelSprite(
        palette: butterflyPalette(0xFF8C42, 0xE05B2B), butterflyGrid)

    private static let boltPalette: [Character: UInt32] = [
        "y": 0xFFE066,
        "Y": 0xFFF7CC,
    ]

    static let lightning = PixelSprite(palette: boltPalette, [
        "...yYy.",
        "..yYy..",
        ".yYy...",
        ".yYyyy.",
        "..yYy..",
        ".yYy...",
        "yYy....",
        "Yy.....",
    ])

    private static let flowerPalette: [Character: UInt32] = [
        "p": 0xFFD23E,  // petals
        "c": 0xFF8C42,  // center
    ]

    static let flower = PixelSprite(palette: flowerPalette, [
        ".p.",
        "pcp",
        ".p.",
    ])
}
