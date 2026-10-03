import AppKit
import ScreenAlignCore

/// A borderless window covering one screen, above everything including the menu bar.
@MainActor
final class OverlayWindow: NSWindow {
    let displayID: DisplayID

    init(screen: NSScreen, state: AppState, controller: AppController) {
        self.displayID = screen.displayID
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        configureAppearance(on: screen)
        contentView = AlignmentView(displayID: displayID, size: screen.frame.size, state: state, controller: controller)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    private func configureAppearance(on screen: NSScreen) {
        setFrame(screen.frame, display: false)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }
}
