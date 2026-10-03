import CoreGraphics

/// How far one display has to move so its lines meet the reference display's lines.
public struct Correction: Equatable, Sendable {
    public let display: DisplayID
    /// Shift in points along the session axis, averaged over all lines.
    public let shift: Int
    /// Spread between the per-line shifts. Above 1 pt the screens have a different
    /// physical size per point, so the cursor can match at one position only.
    public let disagreement: CGFloat

    public var isAligned: Bool { shift == 0 }
    public var hasScaleMismatch: Bool { disagreement >= 1 }
}

extension AlignmentSession {
    public func correction(for display: Display) -> Correction? {
        guard let reference, display.id != reference.id else { return nil }
        let shifts = perLineShifts(of: display, against: reference)
        guard !shifts.isEmpty else { return nil }
        return Correction(display: display.id, shift: averaged(shifts), disagreement: spread(shifts))
    }

    public func pendingCorrections() -> [Correction] {
        participants.compactMap(correction(for:)).filter { !$0.isAligned }
    }

    private func perLineShifts(of display: Display, against reference: Display) -> [CGFloat] {
        zip(lines(on: reference.id), lines(on: display.id)).map { referenceLine, displayLine in
            (reference.frame.start(along: axis) + referenceLine) - (display.frame.start(along: axis) + displayLine)
        }
    }

    private func averaged(_ shifts: [CGFloat]) -> Int {
        Int((shifts.reduce(0, +) / CGFloat(shifts.count)).rounded())
    }

    private func spread(_ shifts: [CGFloat]) -> CGFloat {
        (shifts.max() ?? 0) - (shifts.min() ?? 0)
    }
}
