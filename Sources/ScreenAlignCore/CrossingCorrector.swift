import CoreGraphics

/// Decides where the cursor belongs after it crosses onto another screen. macOS keeps the
/// cursor's point coordinate; this moves it to the spot that physically continues its path.
public struct CrossingCorrector {
    private let displays: [Display]
    private let calibrations: [EdgeCalibration]

    public init(displays: [Display], calibrations: [EdgeCalibration]) {
        self.displays = displays
        self.calibrations = calibrations
    }

    public func correctedLocation(from previous: CGPoint, to current: CGPoint) -> CGPoint? {
        guard let source = display(containing: previous), let target = display(containing: current),
              source.id != target.id, let calibration = calibration(from: source, to: target) else { return nil }

        let corrected = physicalContinuation(of: current, from: source, to: target, using: calibration)
        return abs(corrected.position(along: calibration.axis) - current.position(along: calibration.axis)) >= 1 ? corrected : nil
    }

    /// The two screens involved when the cursor moved from one screen to another.
    public func crossedDisplays(from previous: CGPoint, to current: CGPoint) -> (from: DisplayID, to: DisplayID)? {
        guard let source = display(containing: previous), let target = display(containing: current),
              source.id != target.id else { return nil }
        return (source.id, target.id)
    }

    public var hasCalibrations: Bool { !calibrations.isEmpty && calibrations.contains(where: isUsable) }
}

// MARK: - Leaves

extension CrossingCorrector {
    private func display(containing point: CGPoint) -> Display? {
        displays.first { $0.frame.contains(point) }
    }

    private func calibration(from source: Display, to target: Display) -> EdgeCalibration? {
        calibrations.first { $0.connects(source, to: target) }
            ?? calibrations.first { $0.connects(target, to: source) }?.reversed
    }

    private func physicalContinuation(of point: CGPoint, from source: Display, to target: Display,
                                      using calibration: EdgeCalibration) -> CGPoint {
        let axis = calibration.axis
        let onSource = point.position(along: axis) - source.frame.start(along: axis)
        let onTarget = min(max(calibration.map(onSource), 0), target.frame.length(along: axis) - 1)
        return point.setting((target.frame.start(along: axis) + onTarget).rounded(), along: axis)
    }

    private func isUsable(_ calibration: EdgeCalibration) -> Bool {
        displays.contains { from in displays.contains { calibration.connects(from, to: $0) } }
    }
}
