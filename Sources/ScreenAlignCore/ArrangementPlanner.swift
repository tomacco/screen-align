import CoreGraphics

/// Turns measured edges into display origins. Each screen is placed so its edge lines up
/// with its neighbour in the middle of the part they physically share, and the main
/// display stays at (0, 0) as macOS requires.
public enum ArrangementPlanner {
    public static func origins(for displays: [Display], calibrations: [EdgeCalibration]) -> [DisplayID: CGPoint] {
        let placed = placeAlongEdges(displays, calibrations: calibrations)
        return keepingMainAtZero(placed, displays: displays)
    }
}

// MARK: - Leaves

extension ArrangementPlanner {
    private static func placeAlongEdges(_ displays: [Display], calibrations: [EdgeCalibration]) -> [DisplayID: CGPoint] {
        var origins = Dictionary(uniqueKeysWithValues: displays.map { ($0.id, $0.frame.origin) })
        for hop in Topology.hops(displays) {
            guard let calibration = calibration(for: hop, in: calibrations),
                  let parent = origins[hop.from.id], let child = origins[hop.to.id] else { continue }
            origins[hop.to.id] = child.setting(alignedStart(of: parent, using: calibration), along: hop.axis)
        }
        return origins
    }

    private static func alignedStart(of parent: CGPoint, using calibration: EdgeCalibration) -> CGFloat {
        let span = calibration.sharedSpan ?? 0...calibration.fromLength
        let pivot = (span.lowerBound + span.upperBound) / 2
        return (parent.position(along: calibration.axis) + pivot - calibration.map(pivot)).rounded()
    }

    private static func calibration(for hop: Hop, in calibrations: [EdgeCalibration]) -> EdgeCalibration? {
        calibrations.first { $0.connects(hop.from, to: hop.to) }
            ?? calibrations.first { $0.connects(hop.to, to: hop.from) }?.reversed
    }

    private static func keepingMainAtZero(_ origins: [DisplayID: CGPoint], displays: [Display]) -> [DisplayID: CGPoint] {
        guard let main = displays.first(where: \.isMain), let mainOrigin = origins[main.id] else { return origins }
        return origins.mapValues { CGPoint(x: $0.x - mainOrigin.x, y: $0.y - mainOrigin.y) }
    }
}
