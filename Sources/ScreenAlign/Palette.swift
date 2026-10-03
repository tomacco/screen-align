import AppKit

/// "Calibration": the ScreenAlign palette. Laser-level amber on instrument black, with line
/// colours drawn from the Okabe-Ito set (brightened for a dark backdrop) so they stay distinct
/// under the common forms of colour blindness. Tokens are listed in docs/palette.md.
enum Palette {
    static let ink = NSColor(hex: 0x0E1116)
    static let panel = NSColor(hex: 0x171B22)
    static let panelEdge = NSColor(hex: 0x2A303A)
    static let text = NSColor(hex: 0xE8EAED)
    static let mutedText = NSColor(hex: 0x8B93A1)
    static let guide = NSColor(hex: 0xE8EAED, alpha: 0.85)

    static let lines: [NSColor] = [
        NSColor(hex: 0xFFB020),   // amber
        NSColor(hex: 0x56B4E9),   // sky
        NSColor(hex: 0x2BD9A0),   // mint
        NSColor(hex: 0xE58FC4),   // orchid
        NSColor(hex: 0xFF6A3D),   // vermillion
        NSColor(hex: 0xF0E442),   // lemon
    ]
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}
