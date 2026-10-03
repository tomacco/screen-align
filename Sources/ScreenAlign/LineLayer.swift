import AppKit
import ScreenAlignCore

/// A calibration line: a one-pixel core inside a soft band, with an optional travelling dot.
/// Moves with a spring so the user sees where it went.
final class LineLayer: CALayer {
    private let band = CALayer()
    private let core = CALayer()
    private let dot = CALayer()
    private let halo = CALayer()
    private(set) var axis: Axis = .horizontal
    private static let thickness: CGFloat = 16

    override init() {
        super.init()
        [band, core, halo, dot].forEach(addSublayer)
        dot.bounds = CGRect(x: 0, y: 0, width: 12, height: 12)
        dot.cornerRadius = 6
        halo.bounds = CGRect(x: 0, y: 0, width: 30, height: 30)
        halo.cornerRadius = 15
        hideDot()
    }

    override init(layer: Any) { super.init(layer: layer) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("LineLayer is created in code only") }

    func configure(axis: Axis, in container: CGRect, hairline: CGFloat) {
        self.axis = axis
        bounds = axis == .vertical
            ? CGRect(x: 0, y: 0, width: Self.thickness, height: container.height)
            : CGRect(x: 0, y: 0, width: container.width, height: Self.thickness)
        band.frame = bounds
        core.frame = axis == .vertical
            ? CGRect(x: Self.thickness / 2, y: 0, width: hairline, height: container.height)
            : CGRect(x: 0, y: Self.thickness / 2, width: container.width, height: hairline)
    }

    func paint(_ color: CGColor, band bandColor: CGColor, dot dotColor: CGColor, halo haloColor: CGColor) {
        core.backgroundColor = color
        band.backgroundColor = bandColor
        dot.backgroundColor = dotColor
        halo.backgroundColor = haloColor
    }

    func move(to position: CGFloat, in container: CGRect, animated: Bool) {
        let target = axis == .vertical ? CGPoint(x: position, y: container.midY) : CGPoint(x: container.midX, y: position)
        animated ? spring(to: target) : place(at: target)
    }

    /// Runs the dot along the line between two fractions of its length, inside a repeating cycle.
    func runDot(from start: CGFloat, to end: CGFloat, during window: ClosedRange<Double>, cycle: Double, epoch: CFTimeInterval) {
        let length = axis == .vertical ? bounds.height : bounds.width
        let points = [start, start, end, end].map(dotPoint(length: length))
        let times = [0, window.lowerBound, window.upperBound, 1].map { NSNumber(value: $0) }
        add(keyframes("position", values: points.map { NSValue(point: $0) }, times: times, cycle: cycle, epoch: epoch),
            key: "travel", to: [dot, halo])
        let visible = [0, 0, 1, 1, 0, 0].map { NSNumber(value: $0) }
        let fades = [0, window.lowerBound, window.lowerBound + 0.02, window.upperBound - 0.02, window.upperBound, 1]
        add(keyframes("opacity", values: visible, times: fades.map { NSNumber(value: $0) }, cycle: cycle, epoch: epoch),
            key: "fade", to: [dot, halo])
    }

    func hideDot() {
        [dot, halo].forEach { $0.removeAllAnimations(); $0.opacity = 0 }
    }

    /// A short pulse, used when a line is confirmed.
    func pulse(_ color: CGColor) {
        let flash = CABasicAnimation(keyPath: "backgroundColor")
        flash.toValue = color
        flash.duration = 0.22
        flash.autoreverses = true
        band.add(flash, forKey: "flash")
        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.toValue = 1.04
        grow.duration = 0.22
        grow.autoreverses = true
        band.add(grow, forKey: "grow")
    }
}

// MARK: - Leaves

extension LineLayer {
    private func place(at point: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        position = point
        CATransaction.commit()
    }

    private func spring(to point: CGPoint) {
        let animation = CASpringAnimation(keyPath: "position")
        animation.fromValue = presentation()?.position ?? position
        animation.toValue = point
        animation.damping = 16
        animation.stiffness = 90
        animation.duration = animation.settlingDuration
        place(at: point)
        add(animation, forKey: "move")
    }

    private func dotPoint(length: CGFloat) -> (CGFloat) -> CGPoint {
        { fraction in
            self.axis == .vertical
                ? CGPoint(x: Self.thickness / 2, y: fraction * length)
                : CGPoint(x: fraction * length, y: Self.thickness / 2)
        }
    }

    private func keyframes(_ keyPath: String, values: [Any], times: [NSNumber], cycle: Double, epoch: CFTimeInterval) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = values
        animation.keyTimes = times
        animation.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: values.count - 1)
        animation.duration = cycle
        animation.repeatCount = .infinity
        animation.beginTime = epoch
        animation.fillMode = .both
        return animation
    }

    private func add(_ animation: CAAnimation, key: String, to layers: [CALayer]) {
        layers.forEach { $0.opacity = 1; $0.add(animation, forKey: key) }
    }
}
