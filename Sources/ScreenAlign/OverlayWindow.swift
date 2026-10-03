import AppKit
import ScreenAlignCore

/// A borderless window covering one screen, above everything including the menu bar.
@MainActor
final class OverlayWindow: NSWindow {
    let displayID: DisplayID

    init(screen: NSScreen, content: NSView) {
        self.displayID = screen.displayID
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        configureAppearance(on: screen)
        contentView = content
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

/// One overlay per screen, rebuilt on demand.
@MainActor
final class OverlaySet {
    private(set) var windows: [OverlayWindow] = []

    func show(_ makeContent: (NSScreen) -> NSView) {
        close()
        windows = NSScreen.screens.map { OverlayWindow(screen: $0, content: makeContent($0)) }
        windows.forEach { $0.orderFrontRegardless() }
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        windows.forEach { $0.orderOut(nil) }
        windows = []
    }

    func focus(_ display: DisplayID?) {
        (windows.first { $0.displayID == display } ?? windows.first)?.makeKey()
    }

    func redraw() {
        windows.forEach { $0.contentView?.needsDisplay = true }
    }
}
