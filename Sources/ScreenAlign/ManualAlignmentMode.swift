import AppKit
import ScreenAlignCore

/// Free alignment: lines on every screen, moved by hand, written with Return.
@MainActor
final class ManualAlignmentMode: AlignmentViewDelegate {
    private let state: AppState
    private let overlays = OverlaySet()
    private let onClose: () -> Void
    private var cursorTimer: Timer?

    init(arrangement: DisplayArrangement, aligner: DisplayAligner, onClose: @escaping () -> Void) {
        self.state = AppState(arrangement: arrangement, aligner: aligner)
        self.onClose = onClose
    }

    func start() {
        showOverlays()
        trackCursor()
    }

    func stop() {
        cursorTimer?.invalidate()
        overlays.close()
    }

    func arrangementDidChange() {
        state.session.update(displays: state.displays)
        showOverlays()
    }

    func perform(_ command: Command) {
        execute(command)
        redraw()
    }

    func redraw() {
        overlays.redraw()
    }
}

// MARK: - Leaves

extension ManualAlignmentMode {
    private func showOverlays() {
        overlays.show { screen in
            AlignmentView(displayID: screen.displayID, size: screen.frame.size, state: state, controller: self)
        }
        overlays.focus(state.session.selection.display)
    }

    private func trackCursor() {
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshCursor() }
        }
    }

    private func refreshCursor() {
        let location = CGEvent(source: nil)?.location ?? .zero
        guard state.showsCursorLine, location != state.cursor else { return }
        state.cursor = location
        redraw()
    }

    private func execute(_ command: Command) {
        switch command {
        case .moveLine(let points): state.session.moveSelected(by: points)
        case .selectNextLine: selectNextLine()
        case .addLine: state.session.addLine()
        case .removeLine: state.session.removeSelectedLine()
        case .toggleAxis: toggleAxis()
        case .toggleCursorLine: state.showsCursorLine.toggle()
        case .cycleBackdrop: state.backdrop = state.backdrop.next
        case .apply: state.status = StatusReport.describe(state.aligner.apply(state.session), names: state.displayNames())
        case .undo: state.status = StatusReport.describe(state.aligner.undo())
        case .close: onClose()
        }
    }

    private func selectNextLine() {
        state.session.selectNext()
        overlays.focus(state.session.selection.display)
    }

    private func toggleAxis() {
        state.session.toggleAxis()
        state.status = StatusReport.describe(state.session.axis)
    }
}
