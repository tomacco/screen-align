import CoreGraphics

public enum ApplyOutcome: Equatable {
    case alreadyAligned
    case applied([Correction])
    case failed(ArrangementError)
}

public enum UndoOutcome: Equatable {
    case nothingToUndo
    case restored
    case failed(ArrangementError)
}

/// Writes the session's corrections to the system display arrangement, and can put the
/// previous arrangement back.
public final class DisplayAligner {
    private let arrangement: DisplayArrangement
    private var previousOrigins: [DisplayID: CGPoint]?

    public init(arrangement: DisplayArrangement) {
        self.arrangement = arrangement
    }

    public func apply(_ session: AlignmentSession) -> ApplyOutcome {
        let corrections = session.pendingCorrections()
        guard !corrections.isEmpty else { return .alreadyAligned }

        let displays = arrangement.activeDisplays()
        let targets = targetOrigins(corrections, displays: displays, axis: session.axis)
        return commit(targets, remembering: currentOrigins(displays), corrections: corrections)
    }

    /// Moves displays to explicit origins, keeping the current arrangement for undo.
    public func move(to origins: [DisplayID: CGPoint]) -> Result<Void, ArrangementError> {
        let previous = currentOrigins(arrangement.activeDisplays())
        let result = arrangement.moveDisplays(to: origins)
        if case .success = result { previousOrigins = previous }
        return result
    }

    public func undo() -> UndoOutcome {
        guard let previous = previousOrigins else { return .nothingToUndo }

        previousOrigins = nil
        return restore(previous)
    }
}

// MARK: - Leaves

extension DisplayAligner {
    private func targetOrigins(_ corrections: [Correction], displays: [Display], axis: Axis) -> [DisplayID: CGPoint] {
        let frames = Dictionary(uniqueKeysWithValues: displays.map { ($0.id, $0.frame) })
        return corrections.reduce(into: [:]) { targets, correction in
            guard let frame = frames[correction.display] else { return }
            targets[correction.display] = shifted(frame.origin, by: CGFloat(correction.shift), along: axis)
        }
    }

    private func shifted(_ origin: CGPoint, by shift: CGFloat, along axis: Axis) -> CGPoint {
        axis == .vertical
            ? CGPoint(x: origin.x + shift, y: origin.y)
            : CGPoint(x: origin.x, y: origin.y + shift)
    }

    private func currentOrigins(_ displays: [Display]) -> [DisplayID: CGPoint] {
        Dictionary(uniqueKeysWithValues: displays.map { ($0.id, $0.frame.origin) })
    }

    private func commit(_ targets: [DisplayID: CGPoint], remembering previous: [DisplayID: CGPoint],
                        corrections: [Correction]) -> ApplyOutcome {
        switch arrangement.moveDisplays(to: targets) {
        case .success:
            previousOrigins = previous
            return .applied(corrections)
        case .failure(let error):
            return .failed(error)
        }
    }

    private func restore(_ origins: [DisplayID: CGPoint]) -> UndoOutcome {
        let active = Set(arrangement.activeDisplays().map(\.id))
        switch arrangement.moveDisplays(to: origins.filter { active.contains($0.key) }) {
        case .success: return .restored
        case .failure(let error): return .failed(error)
        }
    }
}
