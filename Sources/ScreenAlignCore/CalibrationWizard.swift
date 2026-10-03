import CoreGraphics

/// One step of the guided calibration: a fixed line on `hop.from` and a line the user moves
/// on `hop.to` until it continues the fixed one.
public struct WizardStep: Equatable, Sendable {
    public let hop: Hop
    /// 0 for the line near the start of the shared edge, 1 for the line near its end.
    public let line: Int
    public let anchor: CGFloat
    public let candidate: CGFloat

    /// True when the moving line sits on the edge of its screen, a hint that the fixed line
    /// may pass outside that screen.
    public var candidateAtEdge: Bool {
        candidate <= 0 || candidate >= hop.to.frame.length(along: hop.axis) - 1
    }
}

public enum WizardEvent: Equatable {
    case nextLine
    case edgeCalibrated
    case retry(CalibrationError)
    case finished
}

/// Walks every shared edge, two lines per edge, and collects one calibration per edge.
public final class CalibrationWizard {
    public let hops: [Hop]
    public private(set) var step: WizardStep?
    public private(set) var calibrations: [EdgeCalibration] = []
    private var samples: [LineSample] = []

    public init(displays: [Display]) {
        hops = Topology.hops(displays)
        step = hops.first.map { makeStep($0, line: 0) }
    }

    public var stepNumber: Int { calibrations.count * 2 + samples.count + 1 }
    public var stepCount: Int { hops.count * 2 }
    public var isFinished: Bool { step == nil }

    public func moveCandidate(by points: CGFloat) {
        guard let current = step else { return }
        placeCandidate(at: current.candidate + points)
    }

    public func placeCandidate(at position: CGFloat) {
        guard let current = step else { return }
        step = makeStep(current.hop, line: current.line, anchor: current.anchor, candidate: position)
    }

    public func confirm() -> WizardEvent {
        guard let current = step else { return .finished }
        samples.append(LineSample(from: current.anchor, to: current.candidate))
        return samples.count < 2 ? startSecondLine(of: current.hop) : finishEdge(current.hop)
    }

    /// The user cannot see the line on the next screen: move the fixed line toward the middle.
    public func reportLineMissesScreen() {
        guard let current = step else { return }
        step = makeStep(current.hop, line: current.line, anchor: nudgedTowardMiddle(current))
    }

    public func goBack() {
        if samples.isEmpty { reopenPreviousEdge() } else { reopenFirstLine() }
    }
}

// MARK: - Leaves

extension CalibrationWizard {
    private static let lineFractions: [CGFloat] = [0.12, 0.88]
    private static let nudge: CGFloat = 0.1
    private static let edgeMargin: CGFloat = 0.04

    private func makeStep(_ hop: Hop, line: Int, anchor: CGFloat? = nil, candidate: CGFloat? = nil) -> WizardStep {
        let fixed = anchor ?? defaultAnchor(hop, line: line)
        let moving = candidate ?? predictedCandidate(hop, anchor: fixed)
        return WizardStep(hop: hop, line: line, anchor: fixed,
                          candidate: clamped(moving.rounded(), within: hop.to.frame.length(along: hop.axis)))
    }

    /// Lines start where both screens are predicted to face each other, so the moving line
    /// lands on its screen without the user having to look for it.
    private func defaultAnchor(_ hop: Hop, line: Int) -> CGFloat {
        let fromLength = hop.from.frame.length(along: hop.axis)
        let span = facingSpan(hop) ?? 0...fromLength
        let anchor = span.lowerBound + Self.lineFractions[line] * (span.upperBound - span.lowerBound)
        return clamped(anchor.rounded(), within: fromLength)
    }

    /// Positions on `from` whose predicted continuation stays inside `to`, with a small margin.
    private func facingSpan(_ hop: Hop) -> ClosedRange<CGFloat>? {
        let fromLength = hop.from.frame.length(along: hop.axis)
        let toLength = hop.to.frame.length(along: hop.axis)
        let prediction = predictor(hop)
        let margin = Self.edgeMargin * toLength
        let ends = [prediction.inverse(margin), prediction.inverse(toLength - margin)]
        let start = max(ends.min() ?? 0, Self.edgeMargin * fromLength)
        let end = min(ends.max() ?? fromLength, fromLength * (1 - Self.edgeMargin))
        return start < end ? start...end : nil
    }

    private func predictedCandidate(_ hop: Hop, anchor: CGFloat) -> CGFloat {
        predictor(hop).map(anchor)
    }

    /// The best guess before the user moves anything. The scale comes from the sizes the
    /// monitors report. The offset comes from the first line of this edge once it is placed,
    /// and before that from today's arrangement, assumed right in the middle of the shared span.
    private func predictor(_ hop: Hop) -> LinearMap {
        let scale = hop.reportedScale
        if let first = samples.first { return LinearMap(scale: scale, through: first.from, first.to) }
        let pivot = sharedMiddle(hop)
        return LinearMap(scale: scale, through: pivot - hop.from.frame.start(along: hop.axis),
                         pivot - hop.to.frame.start(along: hop.axis))
    }

    private func sharedMiddle(_ hop: Hop) -> CGFloat {
        let axis = hop.axis
        let start = max(hop.from.frame.start(along: axis), hop.to.frame.start(along: axis))
        let end = min(hop.from.frame.end(along: axis), hop.to.frame.end(along: axis))
        return start < end ? (start + end) / 2 : hop.from.frame.start(along: axis) + hop.from.frame.length(along: axis) / 2
    }

    private func nudgedTowardMiddle(_ step: WizardStep) -> CGFloat {
        let length = step.hop.from.frame.length(along: step.hop.axis)
        let direction: CGFloat = step.line == 0 ? 1 : -1
        return clamped((step.anchor + direction * Self.nudge * length).rounded(), within: length)
    }

    private func startSecondLine(of hop: Hop) -> WizardEvent {
        step = makeStep(hop, line: 1)
        return .nextLine
    }

    private func finishEdge(_ hop: Hop) -> WizardEvent {
        let measured = samples
        samples = []
        switch EdgeCalibration.solve(hop, samples: measured) {
        case .success(let calibration):
            calibrations.append(calibration)
            return advance()
        case .failure(let error):
            step = makeStep(hop, line: 0)
            return .retry(error)
        }
    }

    private func advance() -> WizardEvent {
        let next = calibrations.count
        step = next < hops.count ? makeStep(hops[next], line: 0) : nil
        return step == nil ? .finished : .edgeCalibrated
    }

    private func reopenFirstLine() {
        guard let first = samples.first, let hop = step?.hop ?? hops[safe: calibrations.count] else { return }
        samples = []
        step = makeStep(hop, line: 0, anchor: first.from, candidate: first.to)
    }

    private func reopenPreviousEdge() {
        guard !calibrations.isEmpty else { return }
        calibrations.removeLast()
        step = makeStep(hops[calibrations.count], line: 0)
    }

    private func clamped(_ position: CGFloat, within length: CGFloat) -> CGFloat {
        min(max(position, 0), length - 1)
    }
}

/// `to = scale * from + offset`, passing through one known pair of positions.
struct LinearMap {
    let scale: CGFloat
    let offset: CGFloat

    init(scale: CGFloat, through from: CGFloat, _ to: CGFloat) {
        self.scale = scale
        self.offset = to - scale * from
    }

    func map(_ position: CGFloat) -> CGFloat { scale * position + offset }
    func inverse(_ position: CGFloat) -> CGFloat { (position - offset) / scale }
}
