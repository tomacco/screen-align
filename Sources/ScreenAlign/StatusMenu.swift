import AppKit
import ServiceManagement

/// The menu bar item: the app lives here while physical crossing runs.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    struct Actions {
        let calibrate: () -> Void
        let manual: () -> Void
        let toggleCrossing: () -> Void
        let undo: () -> Void
        let quit: () -> Void
    }

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let actions: Actions
    private let isCrossingOn: () -> Bool
    private let isCalibrated: () -> Bool

    init(actions: Actions, isCrossingOn: @escaping () -> Bool, isCalibrated: @escaping () -> Bool) {
        self.actions = actions
        self.isCrossingOn = isCrossingOn
        self.isCalibrated = isCalibrated
        super.init()
        item.button?.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: "ScreenAlign")
        item.menu = NSMenu()
        item.menu?.delegate = self
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(crossingItem())
        menu.addItem(.separator())
        menu.addItem(entry("Calibrate…", #selector(calibrate)))
        menu.addItem(entry("Manual alignment…", #selector(manual)))
        menu.addItem(entry("Undo last arrangement change", #selector(undo)))
        menu.addItem(.separator())
        menu.addItem(loginItem())
        menu.addItem(entry("Quit ScreenAlign", #selector(quit), key: "q"))
    }
}

// MARK: - Leaves

extension StatusMenu {
    private func crossingItem() -> NSMenuItem {
        let title = isCalibrated() ? "Physical crossing" : "Physical crossing (calibrate first)"
        let menuItem = entry(title, #selector(toggleCrossing))
        menuItem.state = isCrossingOn() && isCalibrated() ? .on : .off
        menuItem.isEnabled = isCalibrated()
        return menuItem
    }

    private func loginItem() -> NSMenuItem {
        let menuItem = entry("Open at login", #selector(toggleLogin))
        menuItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        return menuItem
    }

    private func entry(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = self
        return menuItem
    }

    @objc private func calibrate() { actions.calibrate() }
    @objc private func manual() { actions.manual() }
    @objc private func toggleCrossing() { actions.toggleCrossing() }
    @objc private func undo() { actions.undo() }
    @objc private func quit() { actions.quit() }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            try service.status == .enabled ? service.unregister() : service.register()
        } catch {
            NSLog("ScreenAlign: open at login failed: \(error)")
        }
    }
}
