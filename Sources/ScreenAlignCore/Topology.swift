import CoreGraphics

/// One shared edge between two neighbouring screens, in the order the wizard visits them.
public struct Hop: Equatable, Sendable {
    public let from: Display
    public let to: Display
    /// `.horizontal` for screens side by side (lines run across, positions are y),
    /// `.vertical` for stacked screens (lines run down, positions are x).
    public let axis: Axis

    public init(from: Display, to: Display, axis: Axis) {
        self.from = from
        self.to = to
        self.axis = axis
    }

    /// True when `to` sits after `from` along the crossing direction (right of it, or below it).
    public var leadsForward: Bool {
        axis == .horizontal ? to.frame.midX > from.frame.midX : to.frame.midY > from.frame.midY
    }
}

/// Finds which screens touch, starting from the left-most screen and walking outwards.
public enum Topology {
    public static func hops(_ displays: [Display]) -> [Hop] {
        guard let start = leftMost(displays) else { return [] }
        return walk(from: start, through: displays)
    }

    public static func sharedEdgeAxis(_ a: CGRect, _ b: CGRect) -> Axis? {
        if touches(a.minX, a.maxX, b.minX, b.maxX) && overlap(a.minY...a.maxY, b.minY...b.maxY) > 0 { return .horizontal }
        if touches(a.minY, a.maxY, b.minY, b.maxY) && overlap(a.minX...a.maxX, b.minX...b.maxX) > 0 { return .vertical }
        return nil
    }
}

// MARK: - Leaves

extension Topology {
    private static let tolerance: CGFloat = 2

    private static func leftMost(_ displays: [Display]) -> Display? {
        displays.min { ($0.frame.minX, $0.frame.minY) < ($1.frame.minX, $1.frame.minY) }
    }

    private static func walk(from start: Display, through displays: [Display]) -> [Hop] {
        var visited: Set<DisplayID> = [start.id]
        var queue = [start]
        var hops: [Hop] = []
        while !queue.isEmpty {
            let current = queue.removeFirst()
            for hop in neighbours(of: current, in: displays) where !visited.contains(hop.to.id) {
                visited.insert(hop.to.id)
                queue.append(hop.to)
                hops.append(hop)
            }
        }
        return hops
    }

    private static func neighbours(of display: Display, in displays: [Display]) -> [Hop] {
        displays
            .filter { $0.id != display.id }
            .sorted { ($0.frame.minX, $0.frame.minY) < ($1.frame.minX, $1.frame.minY) }
            .compactMap { other in sharedEdgeAxis(display.frame, other.frame).map { Hop(from: display, to: other, axis: $0) } }
    }

    private static func touches(_ aStart: CGFloat, _ aEnd: CGFloat, _ bStart: CGFloat, _ bEnd: CGFloat) -> Bool {
        abs(aEnd - bStart) <= tolerance || abs(bEnd - aStart) <= tolerance
    }

    static func overlap(_ a: ClosedRange<CGFloat>, _ b: ClosedRange<CGFloat>) -> CGFloat {
        min(a.upperBound, b.upperBound) - max(a.lowerBound, b.lowerBound)
    }
}
