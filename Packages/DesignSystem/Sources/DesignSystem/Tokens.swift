import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// The palette from `design/BRAND.md`. Raw hex lives here once; views consume
/// tokens by name — no raw hex in views, ever.
public enum FSPalette {
    // Brand blues (from the logo)
    public static let brandNavy: UInt32 = 0x1C3A5F
    public static let brandSteel: UInt32 = 0x4878A8
    public static let brandNavyDeep: UInt32 = 0x12263F

    // Interface neutrals (warm paper)
    public static let paper: UInt32 = 0xFAF6EC
    public static let background: UInt32 = 0xEEF1EC
    public static let ink: UInt32 = 0x2A2926
    public static let inkSoft: UInt32 = 0x6B6A63

    // Status — never used for interaction; navy is never used for status.
    public static let marigold: UInt32 = 0xE2A33B
    public static let clinicRed: UInt32 = 0xC23B3B
    public static let sage: UInt32 = 0x6E8B5E
}

/// Spacing scale, pt. Use the scale; don't invent values.
public enum FSSpace {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 40
}

public enum FSRadius {
    public static let card: CGFloat = 16
    public static let control: CGFloat = 10
    public static let chip: CGFloat = 999
}

/// Minimum hit target (01-ARCHITECTURE.md §9).
public enum FSMetrics {
    public static let minHitTarget: CGFloat = 44
}

#if canImport(SwiftUI)
public extension Color {
    init(fsHex hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    static let fsBrandNavy = Color(fsHex: FSPalette.brandNavy)
    static let fsBrandSteel = Color(fsHex: FSPalette.brandSteel)
    static let fsBrandNavyDeep = Color(fsHex: FSPalette.brandNavyDeep)
    static let fsPaper = Color(fsHex: FSPalette.paper)
    static let fsBackground = Color(fsHex: FSPalette.background)
    static let fsInk = Color(fsHex: FSPalette.ink)
    static let fsInkSoft = Color(fsHex: FSPalette.inkSoft)
    static let fsMarigold = Color(fsHex: FSPalette.marigold)
    static let fsClinicRed = Color(fsHex: FSPalette.clinicRed)
    static let fsSage = Color(fsHex: FSPalette.sage)
}
#endif
