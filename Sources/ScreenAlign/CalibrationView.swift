import AppKit
import ScreenAlignCore

/// One screen during guided calibration: a line, a card that says what to do, and toasts.
@MainActor
final class CalibrationView: NSView {
    let displayID: DisplayID
    let mode: CalibrationMode
    let line = LineLayer()
    var card: Card?
    var cardKey: String?
    var dotEpoch: CFTimeInterval?
    var scene: CalibrationScene?
    var celebrationView: CelebrationView?

    init(displayID: DisplayID, size: NSSize, mode: CalibrationMode) {
        self.displayID = displayID
        self.mode = mode
        super.init(frame: NSRect(origin: .zero, size: size))
        wantsLayer = true
        layer?.addSublayer(line)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("CalibrationView is created in code only") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func render(_ scene: CalibrationScene?, animated: Bool) {
        guard let scene else { return }
        self.scene = scene
        paintBackdrop()
        placeLine(scene, animated: animated)
        runDotIfNeeded(scene)
        showCard(for: scene, animated: animated)
    }

    func pulseLine() {
        line.pulse(resolved(Palette.success, alpha: 0.5))
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        guard let scene else { return }
        dotEpoch = nil
        render(scene, animated: false)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        dragLine(event)
    }

    override func mouseDragged(with event: NSEvent) {
        dragLine(event)
    }

    override func keyDown(with event: NSEvent) {
        if celebrationView != nil { return mode.handleCelebrationKey(event) }
        guard let command = WizardCommand(event) else { return super.keyDown(with: event) }
        mode.handle(command)
    }
}

// MARK: - Leaves

extension CalibrationView {
    private var hairline: CGFloat { 1 / (window?.backingScaleFactor ?? 2) }

    private func paintBackdrop() {
        layer?.backgroundColor = resolved(Palette.ink, alpha: 0.9)
    }

    private func placeLine(_ scene: CalibrationScene, animated: Bool) {
        let color = scene.role == .fixedLine ? Palette.fixedLine : Palette.movingLine
        line.isHidden = scene.role == .waiting
        if line.axis != scene.step.hop.axis || line.bounds.isEmpty { line.configure(axis: scene.step.hop.axis, in: bounds, hairline: hairline) }
        line.paint(resolved(color), band: resolved(color, alpha: 0.16), dot: resolved(Palette.fixedLine),
                   halo: resolved(Palette.fixedLine, alpha: 0.28))
        let position = scene.role == .fixedLine ? scene.step.anchor : scene.step.candidate
        line.move(to: position, in: bounds, animated: animated)
    }

    /// The dot runs along the fixed line to the edge, then continues along the moving line.
    private func runDotIfNeeded(_ scene: CalibrationScene) {
        guard dotEpoch != scene.epoch else { return }
        dotEpoch = scene.epoch
        let forward = scene.step.hop.leadsForward
        switch scene.role {
        case .fixedLine: line.runDot(from: forward ? 0.2 : 0.8, to: forward ? 1 : 0, during: 0...0.5, cycle: 4.4, epoch: scene.epoch)
        case .movingLine: line.runDot(from: forward ? 0 : 1, to: forward ? 0.35 : 0.65, during: 0.5...0.85, cycle: 4.4, epoch: scene.epoch)
        case .waiting: line.hideDot()
        }
    }

    private func dragLine(_ event: NSEvent) {
        guard let scene, scene.role == .movingLine, celebrationView == nil else { return }
        mode.placeLine(at: convert(event.locationInWindow, from: nil).position(along: scene.step.hop.axis))
    }
}
