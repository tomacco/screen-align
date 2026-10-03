import AppKit
import ScreenAlignCore

/// One screen during guided calibration. The screen plays one of three roles in each step:
/// it shows the fixed line, it shows the line to move, or it waits.
@MainActor
final class CalibrationView: NSView {
    let displayID: DisplayID
    let mode: CalibrationMode

    init(displayID: DisplayID, size: NSSize, mode: CalibrationMode) {
        self.displayID = displayID
        self.mode = mode
        super.init(frame: NSRect(origin: .zero, size: size))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("CalibrationView is created in code only") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        drawBackdrop()
        guard let step = mode.wizard.step else { return drawSummary() }
        switch role(in: step) {
        case .fixedLine: drawFixedLine(step)
        case .movingLine: drawMovingLine(step)
        case .waiting: drawWaiting(step)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        dragLine(event)
    }

    override func mouseDragged(with event: NSEvent) {
        dragLine(event)
    }

    override func keyDown(with event: NSEvent) {
        guard let command = WizardCommand(event) else { return super.keyDown(with: event) }
        mode.handle(command)
    }
}

enum CalibrationRole {
    case fixedLine
    case movingLine
    case waiting
}

// MARK: - Input leaves

extension CalibrationView {
    func role(in step: WizardStep) -> CalibrationRole {
        if step.hop.from.id == displayID { return .fixedLine }
        return step.hop.to.id == displayID ? .movingLine : .waiting
    }

    private func dragLine(_ event: NSEvent) {
        guard let step = mode.wizard.step, role(in: step) == .movingLine else { return }
        mode.placeLine(at: convert(event.locationInWindow, from: nil).position(along: step.hop.axis))
    }
}
