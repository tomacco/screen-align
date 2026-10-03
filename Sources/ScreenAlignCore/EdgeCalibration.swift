import CoreGraphics

/// The physical relation across one shared edge: a position on `from` (points from its top,
/// or left) maps to `scale * position + offset` on `to`. `scale` differs from 1 when the two
/// screens have a different physical size per point.
public struct EdgeCalibration: Codable, Equatable, Sendable {
    public let fromKey: String
    public let toKey: String
    public let axis: Axis
    public let scale: CGFloat
    public let offset: CGFloat
    /// Screen lengths along the axis when measured; a resolution change invalidates the calibration.
    public let fromLength: CGFloat
    public let toLength: CGFloat

    public init(fromKey: String, toKey: String, axis: Axis, scale: CGFloat, offset: CGFloat,
                fromLength: CGFloat, toLength: CGFloat) {
        self.fromKey = fromKey
        self.toKey = toKey
        self.axis = axis
        self.scale = scale
        self.offset = offset
        self.fromLength = fromLength
        self.toLength = toLength
    }

    public func map(_ position: CGFloat) -> CGFloat { scale * position + offset }

    public var reversed: EdgeCalibration {
        EdgeCalibration(fromKey: toKey, toKey: fromKey, axis: axis, scale: 1 / scale, offset: -offset / scale,
                        fromLength: toLength, toLength: fromLength)
    }

    /// Positions on `from` that physically face `to`.
    public var sharedSpan: ClosedRange<CGFloat>? {
        let start = max(0, (0 - offset) / scale)
        let end = min(fromLength, (toLength - offset) / scale)
        return start < end ? start...end : nil
    }

    public func connects(_ from: Display, to: Display) -> Bool {
        fromKey == from.key && toKey == to.key
            && fromLength == from.frame.length(along: axis) && toLength == to.frame.length(along: axis)
    }
}

/// One confirmed line: where it sits on each side of the edge.
public struct LineSample: Equatable, Sendable {
    public let from: CGFloat
    public let to: CGFloat

    public init(from: CGFloat, to: CGFloat) {
        self.from = from
        self.to = to
    }
}

public enum CalibrationError: Error, Equatable {
    case needsTwoLines
    case linesTooClose
    case implausibleScale(CGFloat)
}

extension EdgeCalibration {
    private static let minimumSpacing: CGFloat = 20
    private static let plausibleScales: ClosedRange<CGFloat> = 0.25...4

    public static func solve(_ hop: Hop, samples: [LineSample]) -> Result<EdgeCalibration, CalibrationError> {
        guard samples.count == 2 else { return .failure(.needsTwoLines) }
        let (first, second) = (samples[0], samples[1])
        guard abs(second.from - first.from) >= minimumSpacing else { return .failure(.linesTooClose) }

        let scale = (second.to - first.to) / (second.from - first.from)
        guard plausibleScales.contains(scale) else { return .failure(.implausibleScale(scale)) }
        return .success(make(hop, scale: scale, offset: first.to - scale * first.from))
    }

    private static func make(_ hop: Hop, scale: CGFloat, offset: CGFloat) -> EdgeCalibration {
        EdgeCalibration(fromKey: hop.from.key, toKey: hop.to.key, axis: hop.axis, scale: scale, offset: offset,
                        fromLength: hop.from.frame.length(along: hop.axis),
                        toLength: hop.to.frame.length(along: hop.axis))
    }
}

/// Where calibrations live between launches.
public protocol CalibrationStore {
    func load() -> [EdgeCalibration]
    func save(_ calibrations: [EdgeCalibration])
}
