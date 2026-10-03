import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let controller = AppController(arrangement: SystemDisplayArrangement())
    app.setActivationPolicy(.regular)
    app.delegate = controller
    app.run()
}
