import AppKit
import QuartzCore
import ScreenAlignCore

/// Guided calibration: one shared edge at a time, one line at a time.
@MainActor
final class CalibrationMode {
    let wizard: CalibrationWizard
    private(set) var status = ""
    private let overlays = OverlaySet()
    private let onFinish: ([EdgeCalibration]) -> Void
    private let onManual: () -> Void
    private let onCancel: () -> Void
    private var animationTimer: Timer?
    private let startTime = CACurrentMediaTime()

    init(displays: [Display], onFinish: @escaping ([EdgeCalibration]) -> Void,
         onManual: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.wizard = CalibrationWizard(displays: displays)
        self.onFinish = onFinish
        self.onManual = onManual
        self.onCancel = onCancel
    }

    func start() {
        showOverlays()
        animate()
    }

    func stop() {
        animationTimer?.invalidate()
        overlays.close()
    }

    func handle(_ command: WizardCommand) {
        execute(command)
        overlays.redraw()
    }

    func placeLine(at position: CGFloat) {
        wizard.placeCandidate(at: position)
        overlays.redraw()
    }

    /// 0 to 1, repeating every few seconds: drives the dot that travels across the edge.
    var animationPhase: CGFloat {
        CGFloat((CACurrentMediaTime() - startTime).truncatingRemainder(dividingBy: Self.cycle) / Self.cycle)
    }
}

// MARK: - Leaves

extension CalibrationMode {
    private static let cycle: Double = 4.2

    private func showOverlays() {
        overlays.show { screen in
            CalibrationView(displayID: screen.displayID, size: screen.frame.size, mode: self)
        }
        focusMovingLine()
    }

    private func animate() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.overlays.redraw() }
        }
    }

    private func execute(_ command: WizardCommand) {
        switch command {
        case .moveLine(let points): wizard.moveCandidate(by: points)
        case .confirm: confirm()
        case .lineMissesScreen: reportMissedLine()
        case .back: goBack()
        case .switchToManual: onManual()
        case .cancel: onCancel()
        }
    }

    private func confirm() {
        guard !wizard.isFinished else { return onFinish(wizard.calibrations) }
        status = describe(wizard.confirm())
        focusMovingLine()
    }

    private func reportMissedLine() {
        wizard.reportLineMissesScreen()
        status = "Moved the amber line toward the middle. Try again."
    }

    private func goBack() {
        wizard.goBack()
        status = "Went back one step."
        focusMovingLine()
    }

    private func focusMovingLine() {
        overlays.focus(wizard.step?.hop.to.id)
    }

    private func describe(_ event: WizardEvent) -> String {
        switch event {
        case .nextLine: return "First line saved. Now the same near the other end of the edge."
        case .edgeCalibrated: return "Edge measured. Next edge."
        case .finished: return ""
        case .retry(.linesTooClose): return "The two lines were too close together to measure size. This edge starts again."
        case .retry(.implausibleScale): return "Those two lines do not fit together. This edge starts again."
        case .retry(.needsTwoLines): return "This edge needs two lines. It starts again."
        }
    }
}
