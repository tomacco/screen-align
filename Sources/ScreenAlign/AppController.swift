import AppKit
import ScreenAlignCore

/// Owns one overlay window per screen and turns user commands into session changes.
@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private let state: AppState
    private var overlays: [OverlayWindow] = []
    private var cursorTimer: Timer?

    init(arrangement: DisplayArrangement) {
        self.state = AppState(arrangement: arrangement)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        showOverlays()
        observeArrangementChanges()
        trackCursor()
        NSApp.activate(ignoringOtherApps: true)
    }

    func perform(_ command: Command) {
        execute(command)
        redraw()
    }

    func redraw() {
        overlays.forEach { $0.contentView?.needsDisplay = true }
    }
}

// MARK: - Leaves

extension AppController {
    private func showOverlays() {
        overlays.forEach { $0.orderOut(nil) }
        overlays = NSScreen.screens.map { OverlayWindow(screen: $0, state: state, controller: self) }
        overlays.forEach { $0.orderFrontRegardless() }
        focusSelectedScreen()
    }

    private func observeArrangementChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.arrangementDidChange() }
        }
    }

    private func arrangementDidChange() {
        state.session.update(displays: state.displays)
        showOverlays()
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
        case .quit: NSApp.terminate(nil)
        }
    }

    private func selectNextLine() {
        state.session.selectNext()
        focusSelectedScreen()
    }

    private func toggleAxis() {
        state.session.toggleAxis()
        state.status = StatusReport.describe(state.session.axis)
    }

    private func focusSelectedScreen() {
        let selected = overlays.first { $0.displayID == state.session.selection.display }
        (selected ?? overlays.first)?.makeKey()
    }
}
