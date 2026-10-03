import AppKit
#if canImport(Symbols)
import Symbols
#endif

/// "Your screens are aligned": confetti, a seal, and a checklist the cursor ticks off.
@MainActor
final class CelebrationView: NSView {
    private let card = Card(width: 500)
    private var rows: [NSImageView] = []
    private let subtitle = NSTextField.text("Try it: move your cursor across each edge.", size: 16, color: Palette.mutedText)
    private let celebration: Celebration

    init(frame: NSRect, celebration: Celebration) {
        self.celebration = celebration
        super.init(frame: frame)
        wantsLayer = true
        buildCard()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("CelebrationView is created in code only") }

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        layer?.backgroundColor = resolved(Palette.ink, alpha: 0.82)
        layOutCard()
        throwConfetti()
    }

    func refresh() {
        for (index, edge) in celebration.edges.enumerated() where edge.crossed {
            markChecked(rows[index])
        }
        if celebration.allCrossed { subtitle.stringValue = "Perfect. Every edge checks out." }
    }
}

// MARK: - Leaves

extension CelebrationView {
    private func buildCard() {
        let seal = symbol("checkmark.seal.fill", size: 54, color: Palette.success)
        bounce(seal)
        card.stack.alignment = .centerX
        card.stack.spacing = 16
        card.stack.addArrangedSubview(seal)
        card.stack.addArrangedSubview(NSTextField.text("Your screens are aligned", size: 28, weight: .bold))
        card.stack.addArrangedSubview(subtitle)
        card.stack.addArrangedSubview(checklist())
        card.stack.addArrangedSubview(NSStackView.row([
            ActionButton("Done", symbol: "checkmark", primary: true) { [weak self] in self?.celebration.onDone() },
            ActionButton("Undo", symbol: "arrow.uturn.backward") { [weak self] in self?.celebration.onUndo() },
        ], spacing: 10))
        addSubview(card)
    }

    private func checklist() -> NSStackView {
        let list = NSStackView()
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 10
        for edge in celebration.edges {
            let mark = symbol("circle", size: 18, color: Palette.mutedText)
            rows.append(mark)
            list.addArrangedSubview(NSStackView.row([mark, NSTextField.text("\(edge.from.name)  ↔  \(edge.to.name)", size: 15, weight: .medium)], spacing: 10))
        }
        return list
    }

    private func layOutCard() {
        card.layoutSubtreeIfNeeded()
        let size = card.fittingSize
        card.frame = NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }

    private func markChecked(_ mark: NSImageView) {
        guard mark.contentTintColor != Palette.success else { return }
        mark.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 18, weight: .semibold))
        mark.contentTintColor = Palette.success
        bounce(mark)
    }

    private func bounce(_ view: NSImageView) {
        if #available(macOS 14.0, *) { view.addSymbolEffect(.bounce, options: .nonRepeating) }
    }

    /// A short burst of confetti in the palette colours, falling from the top edge.
    private func throwConfetti() {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -10)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: bounds.width, height: 1)
        emitter.emitterCells = Palette.lines.map(confettiCell)
        emitter.beginTime = CACurrentMediaTime()
        layer?.insertSublayer(emitter, at: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { emitter.birthRate = 0 }
    }

    private func confettiCell(_ color: NSColor) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = confettiImage()
        cell.color = resolved(color)
        cell.birthRate = 9
        cell.lifetime = 7
        cell.velocity = 260
        cell.velocityRange = 120
        cell.emissionLongitude = .pi / 2
        cell.emissionRange = .pi / 5
        cell.yAcceleration = 160
        cell.spin = 3
        cell.spinRange = 6
        cell.scale = 0.9
        cell.scaleRange = 0.4
        return cell
    }

    private func confettiImage() -> CGImage? {
        let image = NSImage(size: NSSize(width: 10, height: 6), flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5).fill()
            return true
        }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}

extension CalibrationView {
    func showCelebration(_ celebration: Celebration?) {
        guard let celebration else { return }
        line.isHidden = true
        card?.removeFromSuperview()
        let view = CelebrationView(frame: bounds, celebration: celebration)
        view.alphaValue = 0
        addSubview(view)
        celebrationView = view
        NSAnimationContext.runAnimationGroup { $0.duration = 0.5; view.animator().alphaValue = 1 }
    }

    func refreshCelebration(_ celebration: Celebration) {
        celebrationView?.refresh()
    }
}
