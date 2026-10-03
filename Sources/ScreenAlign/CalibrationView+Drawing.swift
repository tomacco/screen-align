import AppKit
import ScreenAlignCore

extension CalibrationView {
    func drawBackdrop() {
        Palette.ink.withAlphaComponent(0.88).setFill()
        bounds.fill()
    }

    func drawFixedLine(_ step: WizardStep) {
        drawLine(at: step.anchor, axis: step.hop.axis, color: Palette.lines[0])
        drawTravellingDot(step, onFixedScreen: true)
        drawPanel(title: progress(step), lines: fixedLineText(step))
    }

    func drawMovingLine(_ step: WizardStep) {
        drawLine(at: step.candidate, axis: step.hop.axis, color: Palette.lines[1])
        drawTravellingDot(step, onFixedScreen: false)
        if step.candidateAtEdge { drawEdgeHint(step) }
        drawPanel(title: progress(step), lines: movingLineText(step))
    }

    func drawWaiting(_ step: WizardStep) {
        drawPanel(title: progress(step), lines: ["This screen waits for its turn."])
    }

    func drawSummary() {
        drawPanel(title: "Calibration complete", lines: summaryText())
    }
}

// MARK: - Leaves

extension CalibrationView {
    private var hairline: CGFloat { 1 / (window?.backingScaleFactor ?? 2) }

    private func progress(_ step: WizardStep) -> String {
        "Step \(mode.wizard.stepNumber) of \(mode.wizard.stepCount)   \(step.hop.from.name) → \(step.hop.to.name)"
    }

    private func fixedLineText(_ step: WizardStep) -> [String] {
        ["This amber line is fixed.",
         "Follow it to \(step.hop.to.name) and line up the blue line there.",
         mode.status]
    }

    private func movingLineText(_ step: WizardStep) -> [String] {
        ["Move the blue line until it continues the amber line on \(step.hop.from.name).",
         "Drag it, or use the arrow keys (Shift moves 10). Return confirms.",
         "Cannot place it because the amber line would pass outside this screen? Press X.",
         "Delete goes back   M manual mode   Esc cancel",
         mode.status]
    }

    private func summaryText() -> [String] {
        let edges = mode.wizard.calibrations.map { calibration in
            String(format: "%@ to %@: 1 point there = %.2f points here", name(calibration.fromKey), name(calibration.toKey), calibration.scale)
        }
        let intro = edges.isEmpty ? ["Only one screen is connected: there is nothing to calibrate."] : edges
        return intro + ["", "Return writes the arrangement and turns on physical crossing.", "Delete goes back   Esc cancel"]
    }

    private func name(_ key: String) -> String {
        mode.wizard.hops.flatMap { [$0.from, $0.to] }.first { $0.key == key }?.name ?? key
    }

    private func drawLine(at position: CGFloat, axis: Axis, color: NSColor) {
        color.withAlphaComponent(0.16).setFill()
        band(at: position - 7, thickness: 14, axis: axis).fill()
        color.setFill()
        band(at: position, thickness: hairline, axis: axis).fill()
    }

    private func band(at position: CGFloat, thickness: CGFloat, axis: Axis) -> NSRect {
        axis == .vertical
            ? NSRect(x: position, y: 0, width: thickness, height: bounds.height)
            : NSRect(x: 0, y: position, width: bounds.width, height: thickness)
    }

    /// A dot runs along the fixed line to the shared edge, then continues on the next screen.
    private func drawTravellingDot(_ step: WizardStep, onFixedScreen: Bool) {
        guard let along = dotPosition(step, onFixedScreen: onFixedScreen) else { return }
        let across = onFixedScreen ? step.anchor : step.candidate
        let centre = step.hop.axis == .vertical ? NSPoint(x: across, y: along) : NSPoint(x: along, y: across)
        Palette.lines[0].withAlphaComponent(0.25).setFill()
        NSBezierPath(ovalIn: NSRect(x: centre.x - 14, y: centre.y - 14, width: 28, height: 28)).fill()
        Palette.lines[0].setFill()
        NSBezierPath(ovalIn: NSRect(x: centre.x - 6, y: centre.y - 6, width: 12, height: 12)).fill()
    }

    private func dotPosition(_ step: WizardStep, onFixedScreen: Bool) -> CGFloat? {
        let phase = mode.animationPhase
        let span = step.hop.axis == .vertical ? bounds.height : bounds.width
        let forward = step.hop.leadsForward
        if onFixedScreen, phase < 0.55 {
            let progress = eased(phase / 0.55)
            return forward ? span * (0.2 + 0.8 * progress) : span * (0.8 - 0.8 * progress)
        }
        if !onFixedScreen, (0.55..<0.9).contains(phase) {
            let progress = eased((phase - 0.55) / 0.35)
            return forward ? span * 0.35 * progress : span * (1 - 0.35 * progress)
        }
        return nil
    }

    private func eased(_ t: CGFloat) -> CGFloat { t * t * (3 - 2 * t) }

    /// Arrow at the edge the blue line is pinned against, inviting X.
    private func drawEdgeHint(_ step: WizardStep) {
        let atStart = step.candidate <= 0
        let vertical = step.hop.axis == .vertical
        let length = vertical ? bounds.width : bounds.height
        let edge: CGFloat = atStart ? 28 : length - 28
        let mid = vertical ? bounds.midY : bounds.midX
        let tip: CGFloat = atStart ? -14 : 14
        let arrow = NSBezierPath()
        let points = [(mid - 16, edge), (mid + 16, edge), (mid, edge + tip)]
        for (index, point) in points.enumerated() {
            let p = vertical ? NSPoint(x: point.1, y: point.0) : NSPoint(x: point.0, y: point.1)
            index == 0 ? arrow.move(to: p) : arrow.line(to: p)
        }
        arrow.close()
        Palette.lines[1].setFill()
        arrow.fill()
    }

    private func drawPanel(title: String, lines: [String]) {
        let content = panelText(title: title, lines: lines.filter { !$0.isEmpty })
        let size = content.boundingRect(with: NSSize(width: 820, height: 600), options: .usesLineFragmentOrigin).size
        let box = NSRect(x: bounds.midX - size.width / 2 - 20, y: bounds.midY - size.height / 2 - 16,
                         width: size.width + 40, height: size.height + 32)
        let outline = NSBezierPath(roundedRect: box, xRadius: 12, yRadius: 12)
        Palette.panel.withAlphaComponent(0.95).setFill()
        outline.fill()
        Palette.panelEdge.setStroke()
        outline.stroke()
        content.draw(with: box.insetBy(dx: 20, dy: 16), options: .usesLineFragmentOrigin)
    }

    private func panelText(title: String, lines: [String]) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        let text = NSMutableAttributedString(string: title + "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: Palette.mutedText,
            .paragraphStyle: paragraph,
        ])
        text.append(NSAttributedString(string: lines.joined(separator: "\n"), attributes: [
            .font: NSFont.systemFont(ofSize: 17, weight: .regular), .foregroundColor: Palette.text,
            .paragraphStyle: paragraph,
        ]))
        return text
    }
}
