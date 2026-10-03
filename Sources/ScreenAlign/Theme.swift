import AppKit

/// "Calibration": laser-level amber on instrument black in dark mode, ink on paper in light mode.
/// Every colour is dynamic and follows the system appearance. Line colours come from the
/// Okabe-Ito set, so they stay distinct under the common forms of colour blindness.
/// Tokens are listed in docs/palette.md.
enum Palette {
    static let ink = dynamic(dark: 0x0E1116, light: 0xF3F0E8)
    static let panel = dynamic(dark: 0x171B22, light: 0xFFFFFF)
    static let panelEdge = dynamic(dark: 0x2A303A, light: 0xD9D4C7)
    static let text = dynamic(dark: 0xE8EAED, light: 0x1B1F24)
    static let mutedText = dynamic(dark: 0x8B93A1, light: 0x5E6672)
    static let guide = dynamic(dark: 0xE8EAED, light: 0x1B1F24, alpha: 0.85)

    static let amber = dynamic(dark: 0xFFB020, light: 0xC77800)
    static let sky = dynamic(dark: 0x56B4E9, light: 0x1F6FB2)
    static let mint = dynamic(dark: 0x2BD9A0, light: 0x0E9F6E)
    static let orchid = dynamic(dark: 0xE58FC4, light: 0xB4508F)
    static let vermillion = dynamic(dark: 0xFF6A3D, light: 0xD4481B)
    static let lemon = dynamic(dark: 0xF0E442, light: 0x9A8A00)

    static let fixedLine = amber
    static let movingLine = sky
    static let success = mint
    static let lines = [amber, sky, mint, orchid, vermillion, lemon]

    private static func dynamic(dark: UInt32, light: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light, alpha: alpha)
        }
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

extension NSView {
    /// A dynamic colour resolved for this view's appearance, for use in layers.
    func resolved(_ color: NSColor, alpha: CGFloat = 1) -> CGColor {
        var resolved = color.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            resolved = color.withAlphaComponent(color.alphaComponent * alpha).cgColor
        }
        return resolved
    }

    var isDarkAppearance: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
