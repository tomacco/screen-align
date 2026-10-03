import AppKit
import ScreenAlignCore

/// Runs from the menu bar. Opens guided calibration on first use, then keeps physical
/// crossing running in the background.
@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private let arrangement: DisplayArrangement
    private let aligner: DisplayAligner
    private let store: CalibrationStore
    private let crossing: CrossingService
    private var statusMenu: StatusMenu?
    private var calibration: CalibrationMode?
    private var manual: ManualAlignmentMode?
    private var crossingWanted = true

    init(arrangement: DisplayArrangement, store: CalibrationStore) {
        self.arrangement = arrangement
        self.aligner = DisplayAligner(arrangement: arrangement)
        self.store = store
        self.crossing = CrossingService(arrangement: arrangement)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusMenu()
        observeArrangementChanges()
        crossing.use(store.load())
        crossing.onEdgeCrossed = { [weak self] in self?.calibration?.markCrossed($0, $1) }
        if Launch.previewCelebration { return previewCelebration() }
        if Launch.openCalibration { return startCalibration() }
        crossing.isCalibrated ? resumeCrossing() : startCalibration()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        startCalibration()
        return false
    }
}

// MARK: - Leaves

extension AppController {
    private func installStatusMenu() {
        statusMenu = StatusMenu(
            actions: .init(calibrate: { [weak self] in self?.startCalibration() },
                           manual: { [weak self] in self?.startManual() },
                           toggleCrossing: { [weak self] in self?.toggleCrossing() },
                           undo: { [weak self] in _ = self?.aligner.undo() },
                           quit: { NSApp.terminate(nil) }),
            isCrossingOn: { [weak self] in self?.crossing.isRunning ?? false },
            isCalibrated: { [weak self] in self?.crossing.isCalibrated ?? false })
    }

    private func observeArrangementChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.arrangementDidChange() }
        }
    }

    private func arrangementDidChange() {
        crossing.refreshDisplays()
        manual?.arrangementDidChange()
    }

    private func startCalibration() {
        closeOverlays()
        crossing.stop()
        calibration = CalibrationMode(
            displays: arrangement.activeDisplays(),
            onFinish: { [weak self] in self?.finishCalibration($0) },
            onManual: { [weak self] in self?.startManual() },
            onCancel: { [weak self] in self?.returnToBackground() })
        calibration?.start()
    }

    private func startManual() {
        closeOverlays()
        crossing.stop()
        manual = ManualAlignmentMode(arrangement: arrangement, aligner: aligner,
                                     onClose: { [weak self] in self?.returnToBackground() })
        manual?.start()
    }

    /// Writes the result, turns physical crossing on, and lets the user try it on the final screen.
    private func finishCalibration(_ calibrations: [EdgeCalibration]) {
        store.save(calibrations)
        _ = aligner.move(to: ArrangementPlanner.origins(for: arrangement.activeDisplays(), calibrations: calibrations))
        crossing.use(calibrations)
        crossingWanted = true
        crossing.start()
        calibration?.celebrate(onDone: { [weak self] in self?.returnToBackground() },
                               onUndo: { [weak self] in self?.undoCalibration() })
    }

    private func undoCalibration() {
        _ = aligner.undo()
        returnToBackground()
    }

    /// `-previewCelebration YES` shows the final screen without measuring or writing anything.
    private func previewCelebration() {
        startCalibration()
        crossing.start()
        calibration?.celebrate(onDone: { NSApp.terminate(nil) }, onUndo: { NSApp.terminate(nil) })
    }

    private func returnToBackground() {
        closeOverlays()
        crossing.refreshDisplays()
        resumeCrossing()
    }

    private func resumeCrossing() {
        if crossingWanted && crossing.isCalibrated { crossing.start() }
    }

    private func toggleCrossing() {
        crossingWanted = !crossing.isRunning
        crossingWanted ? crossing.start() : crossing.stop()
    }

    private func closeOverlays() {
        calibration?.stop()
        calibration = nil
        manual?.stop()
        manual = nil
    }
}

enum Launch {
    static var previewCelebration: Bool { UserDefaults.standard.bool(forKey: "previewCelebration") }
    /// `-calibrate YES` opens the wizard at launch even when a calibration exists.
    static var openCalibration: Bool { UserDefaults.standard.bool(forKey: "calibrate") }
}
