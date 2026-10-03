import AppKit
import QuartzCore
import ScreenAlignCore

/// What one screen shows during a calibration step.
struct CalibrationScene {
    enum Role { case fixedLine, movingLine, waiting }

    let role: Role
    let step: WizardStep
    let stepNumber: Int
    let stepCount: Int
    /// Shared start time of the travelling dot, so it hands over between screens in sync.
    let epoch: CFTimeInterval
}

/// Guided calibration: one shared edge at a time, one line at a time.
@MainActor
final class CalibrationMode {
    let wizard: CalibrationWizard
    private let overlays = OverlaySet()
    private let onFinish: ([EdgeCalibration]) -> Void
    private let onManual: () -> Void
    private let onCancel: () -> Void
    private var epoch = CACurrentMediaTime()
    private var isTransitioning = false
    private var celebration: Celebration?

    init(displays: [Display], onFinish: @escaping ([EdgeCalibration]) -> Void,
         onManual: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.wizard = CalibrationWizard(displays: displays)
        self.onFinish = onFinish
        self.onManual = onManual
        self.onCancel = onCancel
    }

    func start() {
        showOverlays()
        render(animated: false)
    }

    func stop() {
        overlays.close()
    }

    func handle(_ command: WizardCommand) {
        guard !isTransitioning, celebration == nil else { return }
        execute(command)
    }

    func placeLine(at position: CGFloat) {
        guard !isTransitioning else { return }
        wizard.placeCandidate(at: position)
        render(animated: false)
    }

    func celebrate(onDone: @escaping () -> Void, onUndo: @escaping () -> Void) {
        celebration = Celebration(hops: wizard.hops, onDone: onDone, onUndo: onUndo)
        views.forEach { $0.showCelebration(celebration) }
        Feedback.celebrate()
    }

    func markCrossed(_ from: DisplayID, _ to: DisplayID) {
        guard let celebration, celebration.check(from, to) else { return }
        views.forEach { $0.refreshCelebration(celebration) }
        Feedback.edgeChecked()
    }

    func handleCelebrationKey(_ event: NSEvent) {
        guard let celebration else { return }
        event.charactersIgnoringModifiers?.lowercased() == "u" ? celebration.onUndo() : celebration.onDone()
    }
}

// MARK: - Leaves

extension CalibrationMode {
    private static let confirmPause: TimeInterval = 0.55
    private static let lineGlide: TimeInterval = 0.9

    private var views: [CalibrationView] { overlays.windows.compactMap { $0.contentView as? CalibrationView } }

    private func showOverlays() {
        overlays.show { screen in CalibrationView(displayID: screen.displayID, size: screen.frame.size, mode: self) }
        overlays.focus(wizard.step?.hop.to.id)
    }

    private func execute(_ command: WizardCommand) {
        switch command {
        case .moveLine(let points): moveLine(by: points)
        case .confirm: confirmLine()
        case .lineMissesScreen: retryWithAnotherLine()
        case .back: goBack()
        case .switchToManual: onManual()
        case .cancel: onCancel()
        }
    }

    private func moveLine(by points: CGFloat) {
        wizard.moveCandidate(by: points)
        render(animated: false)
    }

    /// The confirmed line pulses, then the next step glides in.
    private func confirmLine() {
        guard let step = wizard.step else { return }
        isTransitioning = true
        Feedback.lineConfirmed()
        view(for: step.hop.to.id)?.pulseLine()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.confirmPause) { [weak self] in
            self?.advance()
        }
    }

    private func advance() {
        let event = wizard.confirm()
        isTransitioning = false
        guard event != .finished else { return onFinish(wizard.calibrations) }
        restartDot(after: Self.lineGlide)
        render(animated: true)
        if case .retry = event { toast("Those lines did not fit together. Let's redo this edge.", symbol: "arrow.counterclockwise") }
        overlays.focus(wizard.step?.hop.to.id)
    }

    /// The fixed line glides to a new spot, a toast says where, and the dot replays.
    private func retryWithAnotherLine() {
        guard let step = wizard.step else { return }
        wizard.reportLineMissesScreen()
        Feedback.lineMoved()
        restartDot(after: Self.lineGlide)
        render(animated: true)
        toast(movedDirection(step), symbol: step.line == 0 ? "arrow.down" : "arrow.up")
    }

    private func goBack() {
        wizard.goBack()
        restartDot(after: Self.lineGlide)
        render(animated: true)
        toast("Back one step", symbol: "chevron.backward")
        overlays.focus(wizard.step?.hop.to.id)
    }

    private func restartDot(after delay: TimeInterval) {
        epoch = CACurrentMediaTime() + delay
    }

    private func render(animated: Bool) {
        views.forEach { $0.render(scene(for: $0.displayID), animated: animated) }
    }

    private func scene(for display: DisplayID) -> CalibrationScene? {
        guard let step = wizard.step else { return nil }
        let role: CalibrationScene.Role = step.hop.from.id == display ? .fixedLine
            : step.hop.to.id == display ? .movingLine : .waiting
        return CalibrationScene(role: role, step: step, stepNumber: wizard.stepNumber,
                                stepCount: wizard.stepCount, epoch: epoch)
    }

    private func view(for display: DisplayID) -> CalibrationView? {
        views.first { $0.displayID == display }
    }

    private func toast(_ message: String, symbol: String) {
        guard let step = wizard.step else { return }
        [step.hop.from.id, step.hop.to.id].compactMap(view(for:)).forEach { $0.showToast(message, symbol: symbol) }
    }

    private func movedDirection(_ step: WizardStep) -> String {
        let forward = step.line == 0
        let word = step.hop.axis == .vertical ? (forward ? "right" : "left") : (forward ? "down" : "up")
        return "Trying a line further \(word)"
    }
}
