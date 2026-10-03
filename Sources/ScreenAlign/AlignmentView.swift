import AppKit
import ScreenAlignCore

/// Draws the lines, the cursor guide and the info panel for one screen, and takes mouse and key input.
@MainActor
final class AlignmentView: NSView {
    let displayID: DisplayID
    let state: AppState
    weak var controller: AppController?
    var draggedLine: Int?

    init(displayID: DisplayID, size: NSSize, state: AppState, controller: AppController) {
        self.displayID = displayID
        self.state = state
        self.controller = controller
        super.init(frame: NSRect(origin: .zero, size: size))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("AlignmentView is created in code only") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let display = state.display(displayID) else { return }
        drawBackdrop()
        drawLines()
        drawCursorLine(on: display)
        drawPanel(for: display)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        grabNearestLine(at: position(of: event))
        controller?.redraw()
    }

    override func mouseDragged(with event: NSEvent) {
        dragSelectedLine(to: position(of: event))
        controller?.redraw()
    }

    override func mouseUp(with event: NSEvent) {
        draggedLine = nil
    }

    override func keyDown(with event: NSEvent) {
        guard let command = Command(event) else { return super.keyDown(with: event) }
        controller?.perform(command)
    }
}
