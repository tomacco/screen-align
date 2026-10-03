import AppKit
import ScreenAlignCore

extension AlignmentView {
    private static let help = """
        drag / arrows move line (shift x10)   Tab next line   N add line   Delete remove line
        V switch axis   T cursor line   B background   Return APPLY   U undo   Esc quit
        """

    func drawBackdrop() {
        Palette.ink.withAlphaComponent(state.backdrop.opacity).setFill()
        bounds.fill()
    }

    func drawLines() {
        for (index, position) in state.session.lines(on: displayID).enumerated() {
            drawLine(index, at: position, color: Palette.lines[index % Palette.lines.count])
        }
    }

    func drawCursorLine(on display: Display) {
        let axis = state.session.axis
        let position = state.cursor.position(along: axis) - display.frame.start(along: axis)
        guard state.showsCursorLine, (0..<display.frame.length(along: axis)).contains(position) else { return }
        strokeDashed(across: position)
    }

    func drawPanel(for display: Display) {
        let text = StatusReport.describe(display, in: state.session) + "\n\n" + Self.help + "\n" + state.status
        let content = NSAttributedString(string: text, attributes: Self.panelAttributes)
        let box = panelBox(for: content)
        let outline = NSBezierPath(roundedRect: box, xRadius: 8, yRadius: 8)
        Palette.panel.withAlphaComponent(0.94).setFill()
        outline.fill()
        Palette.panelEdge.setStroke()
        outline.stroke()
        content.draw(with: box.insetBy(dx: 12, dy: 8), options: .usesLineFragmentOrigin)
    }
}

// MARK: - Leaves

extension AlignmentView {
    private static let panelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
        .foregroundColor: Palette.text,
    ]

    private var axis: Axis { state.session.axis }
    private var hairline: CGFloat { 1 / (window?.backingScaleFactor ?? 2) }
    private var span: CGFloat { axis == .vertical ? bounds.height : bounds.width }

    private func drawLine(_ index: Int, at position: CGFloat, color: NSColor) {
        if state.session.selection == LineSelection(display: displayID, line: index) {
            color.withAlphaComponent(0.18).setFill()
            bar(at: position - 6, thickness: 12).fill()
        }
        color.setFill()
        bar(at: position, thickness: hairline).fill()
        bar(at: position - 8, thickness: 16 + hairline, from: 0, length: 3).fill()
        bar(at: position - 8, thickness: 16 + hairline, from: span - 3, length: 3).fill()
        drawLabel(index, at: position, color: color)
    }

    /// A rect `thickness` wide at `position` across the axis, running `length` points from `from`.
    private func bar(at position: CGFloat, thickness: CGFloat, from start: CGFloat = 0, length: CGFloat? = nil) -> NSRect {
        let run = length ?? span
        return axis == .vertical
            ? NSRect(x: position, y: start, width: thickness, height: run)
            : NSRect(x: start, y: position, width: run, height: thickness)
    }

    private func drawLabel(_ index: Int, at position: CGFloat, color: NSColor) {
        let text = "\(index + 1)  \(axis == .vertical ? "x" : "y")=\(Int(position))"
        let origin = axis == .vertical
            ? NSPoint(x: position + 6, y: bounds.midY - 160)
            : NSPoint(x: bounds.midX - 40, y: position - 20)
        NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium), .foregroundColor: color,
        ]).draw(at: origin)
    }

    private func strokeDashed(across position: CGFloat) {
        let path = NSBezierPath()
        path.move(to: axis == .vertical ? NSPoint(x: position, y: 0) : NSPoint(x: 0, y: position))
        path.line(to: axis == .vertical ? NSPoint(x: position, y: span) : NSPoint(x: span, y: position))
        path.lineWidth = hairline
        path.setLineDash([6, 4], count: 2, phase: 0)
        Palette.guide.setStroke()
        path.stroke()
    }

    private func panelBox(for content: NSAttributedString) -> NSRect {
        let size = content.boundingRect(with: NSSize(width: 760, height: 400), options: .usesLineFragmentOrigin).size
        return NSRect(x: bounds.midX - size.width / 2 - 12, y: bounds.height - size.height - 60,
                      width: size.width + 24, height: size.height + 16)
    }
}
