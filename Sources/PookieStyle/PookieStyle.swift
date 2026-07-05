import SwiftUI

// MARK: - Color tokens

public extension Color {
    static let pookieBg         = Color(hex: "eef2f8")
    static let pookieSurface    = Color(hex: "ffffff")
    static let pookieSurface2   = Color(hex: "e5ecf6")
    static let pookieText       = Color(hex: "2a3444")
    static let pookieTextMuted  = Color(hex: "8b95a6")
    static let pookieTextFaint  = Color(hex: "bcc5d4")
    static let pookieBorder     = Color(hex: "e3eaf4")
    static let pookieAccent     = Color(hex: "3160c9")

    // color-mix(in srgb, #3160c9 72%, #2a3444) → #2f54a4
    static let pookieAccentInk  = Color(hex: "2f54a4")

    // color-mix(in srgb, #2a3444 62%, #b04a3a) → #5d3c40 (deductions stay reddish, per the design)
    static let pookieNegative   = Color(hex: "5d3c40")

    // Accent tints — rendered as opacity overlays (suitable over light surface)
    static let pookieAccentSoft = Color(hex: "3160c9").opacity(0.12)
    static let pookieAccentLine = Color(hex: "3160c9").opacity(0.26)

    // Weekend cell background — muted blue-gray, heavier than accentSoft to read as "weekend"
    static let pookieWeekend    = Color(hex: "ccd4e0")
}

// MARK: - Typography

public extension Font {
    static func pookie(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Quicksand", size: size).weight(weight)
    }
}

// MARK: - Corner radii

public enum PookieRadius {
    public static let lg: CGFloat = 22
    public static let md: CGFloat = 16
    public static let sm: CGFloat = 12
}

// MARK: - View modifiers

public extension View {
    func pookieShadow() -> some View {
        shadow(color: Color(hex: "283C64").opacity(0.04), radius: 1,  x: 0, y: 1)
            .shadow(color: Color(hex: "32508C").opacity(0.08), radius: 14, x: 0, y: 10)
    }

    func pookieCard(radius: CGFloat = PookieRadius.lg) -> some View {
        background(Color.pookieSurface)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .pookieShadow()
    }
}

// MARK: - Hex colour init (internal)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double(int         & 0xFF) / 255
        )
    }
}
