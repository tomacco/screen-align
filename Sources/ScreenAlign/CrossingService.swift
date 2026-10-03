import AppKit
import ScreenAlignCore

/// Watches the cursor and, when it crosses onto another screen, moves it to the spot that
/// physically continues its path. Needs no special permission: it polls the cursor position
/// and uses CGWarpMouseCursorPosition.
@MainActor
final class CrossingService {
    private let arrangement: DisplayArrangement
    private var calibrations: [EdgeCalibration] = []
    private var corrector = CrossingCorrector(displays: [], calibrations: [])
    private var timer: Timer?
    private var previous: CGPoint?
    private let warpSource = CGEventSource(stateID: .combinedSessionState)

    init(arrangement: DisplayArrangement) {
        self.arrangement = arrangement
        warpSource?.localEventsSuppressionInterval = 0
    }

    /// Called whenever the cursor moves from one screen to another.
    var onEdgeCrossed: ((DisplayID, DisplayID) -> Void)?

    var isRunning: Bool { timer != nil }
    var isCalibrated: Bool { corrector.hasCalibrations }

    func use(_ calibrations: [EdgeCalibration]) {
        self.calibrations = calibrations
        refreshDisplays()
    }

    func refreshDisplays() {
        corrector = CrossingCorrector(displays: arrangement.activeDisplays(), calibrations: calibrations)
        previous = nil
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.followCursor() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        previous = nil
    }
}

// MARK: - Leaves

extension CrossingService {
    private func followCursor() {
        let current = CGEvent(source: nil)?.location ?? .zero
        reportCrossing(to: current)
        guard !isDragging(), let last = previous,
              let corrected = corrector.correctedLocation(from: last, to: current) else {
            previous = current
            return
        }
        warp(to: corrected)
        previous = corrected
    }

    private func reportCrossing(to current: CGPoint) {
        guard let last = previous, let crossed = corrector.crossedDisplays(from: last, to: current) else { return }
        onEdgeCrossed?(crossed.from, crossed.to)
    }

    /// Warping during a drag can drop the drag, so window and file drags cross uncorrected.
    private func isDragging() -> Bool {
        CGEventSource.buttonState(.combinedSessionState, button: .left)
    }

    private func warp(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        CGAssociateMouseAndMouseCursorPosition(1)
    }
}
