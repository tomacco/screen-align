import AppKit

/// A button that runs a closure.
final class ActionButton: NSButton {
    private let handler: () -> Void

    init(_ title: String, symbol: String? = nil, primary: Bool = false, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        configure(title: title, symbol: symbol, primary: primary)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("ActionButton is created in code only") }

    private func configure(title: String, symbol: String?, primary: Bool) {
        self.title = title
        bezelStyle = .push
        controlSize = .large
        refusesFirstResponder = true
        if let symbol { image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil); imagePosition = .imageLeading }
        if primary { bezelColor = Palette.movingLine; keyEquivalent = "" }
        target = self
        action = #selector(run)
    }

    @objc private func run() { handler() }
}

/// A key drawn as a keycap, for hints like "⏎ Matches".
final class KeyCap: NSTextField {
    init(_ key: String) {
        super.init(frame: .zero)
        stringValue = key
        isEditable = false
        isBordered = false
        drawsBackground = false
        alignment = .center
        font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        textColor = Palette.text
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.borderWidth = 1
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(greaterThanOrEqualToConstant: 26).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("KeyCap is created in code only") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.borderColor = resolved(Palette.mutedText, alpha: 0.6)
        layer?.backgroundColor = resolved(Palette.mutedText, alpha: 0.12)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        viewDidChangeEffectiveAppearance()
    }
}

/// One dot per step: done steps filled, the current one pulsing, the rest hollow.
final class ProgressDots: NSView {
    private let total: Int
    private let current: Int

    init(current: Int, total: Int) {
        self.current = current
        self.total = total
        super.init(frame: NSRect(x: 0, y: 0, width: CGFloat(total) * 22, height: 12))
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: frame.width).isActive = true
        heightAnchor.constraint(equalToConstant: 12).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("ProgressDots is created in code only") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        (1...max(total, 1)).forEach(addDot)
    }

    private func addDot(_ step: Int) {
        let dot = CALayer()
        dot.frame = CGRect(x: CGFloat(step - 1) * 22, y: 0, width: step == current ? 18 : 12, height: 12)
        dot.cornerRadius = 6
        dot.borderWidth = 1.5
        dot.borderColor = resolved(step < current ? Palette.success : step == current ? Palette.fixedLine : Palette.mutedText)
        dot.backgroundColor = step < current ? resolved(Palette.success) : step == current ? resolved(Palette.fixedLine) : nil
        if step == current { breathe(dot) }
        layer?.addSublayer(dot)
    }

    private func breathe(_ dot: CALayer) {
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1
        pulse.toValue = 0.45
        pulse.duration = 0.9
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        dot.add(pulse, forKey: "breathe")
    }
}

/// A frosted card in the native HUD material.
final class Card: NSVisualEffectView {
    let stack = NSStackView()

    init(width: CGFloat) {
        super.init(frame: .zero)
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.masksToBounds = true
        configureStack(width: width)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Card is created in code only") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        matchAppearance()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        matchAppearance()
    }

    private func matchAppearance() {
        material = isDarkAppearance ? .hudWindow : .popover
        layer?.borderWidth = 1
        layer?.borderColor = resolved(Palette.panelEdge)
    }

    private func configureStack(width: CGFloat) {
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 22, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: width),
        ])
    }
}

extension NSTextField {
    static func text(_ string: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = Palette.text) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: string)
        field.preferredMaxLayoutWidth = 440
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        return field
    }
}

extension NSStackView {
    static func row(_ views: [NSView], spacing: CGFloat = 8) -> NSStackView {
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.spacing = spacing
        row.alignment = .centerY
        return row
    }
}

/// "⏎ Matches" style hint.
func keyHint(_ keys: [String], _ label: String) -> NSStackView {
    .row(keys.map(KeyCap.init) + [NSTextField.text(label, size: 13, color: Palette.mutedText)], spacing: 5)
}

func symbol(_ name: String, size: CGFloat, color: NSColor) -> NSImageView {
    let view = NSImageView()
    view.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: size, weight: .semibold))
    view.contentTintColor = color
    return view
}
