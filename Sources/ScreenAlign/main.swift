import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let controller = AppController(arrangement: SystemDisplayArrangement(), store: UserDefaultsCalibrationStore())
    app.setActivationPolicy(.accessory)
    app.delegate = controller
    app.run()
}
