import AppKit
import ScreenAlignCore

extension CalibrationView {
    func showCard(for scene: CalibrationScene, animated: Bool) {
        let key = "\(scene.role)-\(scene.stepNumber)-\(scene.step.candidateAtEdge)"
        guard key != cardKey else { return }
        cardKey = key
        replaceCard(with: makeCard(scene), animated: animated)
    }

    func showToast(_ message: String, symbol name: String) {
        let toast = Card(width: 340)
        toast.stack.addArrangedSubview(NSStackView.row([symbol(name, size: 15, color: Palette.fixedLine),
                                             NSTextField.text(message, size: 15, weight: .medium)]))
        toast.stack.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        place(toast, centredAt: NSPoint(x: bounds.midX, y: bounds.height * 0.3))
        fadeIn(toast, then: 1.8)
    }
}

// MARK: - Leaves

extension CalibrationView {
    private func makeCard(_ scene: CalibrationScene) -> Card {
        switch scene.role {
        case .fixedLine: return fixedLineCard(scene)
        case .movingLine: return movingLineCard(scene)
        case .waiting: return waitingCard(scene)
        }
    }

    private func fixedLineCard(_ scene: CalibrationScene) -> Card {
        let card = Card(width: 420)
        card.stack.addArrangedSubview(progressRow(scene))
        card.stack.addArrangedSubview(NSStackView.row([symbol("lock.fill", size: 18, color: Palette.fixedLine),
                                            NSTextField.text("This amber line stays put", size: 21, weight: .semibold)], spacing: 10))
        card.stack.addArrangedSubview(NSTextField.text("Watch it travel onto \(scene.step.hop.to.name).", size: 15, color: Palette.mutedText))
        return card
    }

    private func movingLineCard(_ scene: CalibrationScene) -> Card {
        let card = Card(width: 500)
        card.stack.addArrangedSubview(progressRow(scene))
        card.stack.addArrangedSubview(NSTextField.text("Slide the blue line until it continues the amber one", size: 21, weight: .semibold))
        if scene.step.candidateAtEdge { card.stack.addArrangedSubview(edgeWarning(scene)) }
        card.stack.addArrangedSubview(NSStackView.row([moveHint(scene), keyHint(["⏎"], "Matches"), keyHint(["X"], "Not here")], spacing: 18))
        card.stack.addArrangedSubview(NSStackView.row([
            ActionButton("Matches", symbol: "checkmark", primary: true) { [weak self] in self?.mode.handle(.confirm) },
            ActionButton("Not on this screen", symbol: "eye.slash") { [weak self] in self?.mode.handle(.lineMissesScreen) },
            ActionButton("Back", symbol: "chevron.backward") { [weak self] in self?.mode.handle(.back) },
        ], spacing: 10))
        return card
    }

    private func waitingCard(_ scene: CalibrationScene) -> Card {
        let card = Card(width: 300)
        card.stack.addArrangedSubview(ProgressDots(current: scene.stepNumber, total: scene.stepCount))
        card.stack.addArrangedSubview(NSTextField.text("Waiting for its turn", size: 17, weight: .medium, color: Palette.mutedText))
        return card
    }

    private func progressRow(_ scene: CalibrationScene) -> NSStackView {
        .row([ProgressDots(current: scene.stepNumber, total: scene.stepCount),
              NSTextField.text("\(scene.step.hop.from.name)  →  \(scene.step.hop.to.name)", size: 12, weight: .medium, color: Palette.mutedText)],
             spacing: 12)
    }

    private func moveHint(_ scene: CalibrationScene) -> NSStackView {
        keyHint(scene.step.hop.axis == .vertical ? ["←", "→"] : ["↑", "↓"], "or drag")
    }

    private func edgeWarning(_ scene: CalibrationScene) -> NSStackView {
        .row([symbol("exclamationmark.triangle.fill", size: 14, color: Palette.fixedLine),
              NSTextField.text("Stuck at the edge? The amber line may miss this screen. Choose Not on this screen.", size: 13,
                               color: Palette.mutedText)])
    }

    private func replaceCard(with next: Card, animated: Bool) {
        let previous = card
        card = next
        place(next, centredAt: NSPoint(x: bounds.midX, y: bounds.midY))
        guard animated else { previous?.removeFromSuperview(); return }
        next.alphaValue = 0
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.45
            next.animator().alphaValue = 1
            previous?.animator().alphaValue = 0
        }, completionHandler: { previous?.removeFromSuperview() })
    }

    func place(_ view: NSView, centredAt centre: NSPoint) {
        addSubview(view)
        view.layoutSubtreeIfNeeded()
        let size = view.fittingSize
        view.frame = NSRect(x: centre.x - size.width / 2, y: centre.y - size.height / 2, width: size.width, height: size.height)
    }

    private func fadeIn(_ view: NSView, then hold: TimeInterval) {
        view.alphaValue = 0
        NSAnimationContext.runAnimationGroup { $0.duration = 0.3; view.animator().alphaValue = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.5; view.animator().alphaValue = 0 },
                                                 completionHandler: { view.removeFromSuperview() })
        }
    }
}
