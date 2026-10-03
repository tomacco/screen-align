import CoreGraphics

/// The text shown to the user: per-display state and the result of the last action.
public enum StatusReport {
    public static func describe(_ display: Display, in session: AlignmentSession) -> String {
        let header = "\(display.name)  \(size(display.frame)) pt @ (\(Int(display.frame.minX)), \(Int(display.frame.minY)))"
        return header + "\n" + state(of: display, in: session)
    }

    public static func describe(_ outcome: ApplyOutcome, names: [DisplayID: String]) -> String {
        switch outcome {
        case .alreadyAligned: return "Already aligned. Nothing to write."
        case .applied(let corrections): return "Applied: " + listed(corrections, names: names) + ". U undoes."
        case .failed(let error): return "Apply failed: \(error)."
        }
    }

    public static func describe(_ outcome: UndoOutcome) -> String {
        switch outcome {
        case .nothingToUndo: return "Nothing to undo."
        case .restored: return "Restored the previous arrangement."
        case .failed(let error): return "Undo failed: \(error)."
        }
    }

    public static func describe(_ axis: Axis) -> String {
        axis == .vertical
            ? "Vertical lines: aligning stacked screens left and right."
            : "Horizontal lines: aligning side-by-side screens."
    }
}

// MARK: - Leaves

extension StatusReport {
    private static func state(of display: Display, in session: AlignmentSession) -> String {
        if display.isMain { return "Reference display, stays fixed." }
        guard let correction = session.correction(for: display) else { return notInPass(session.axis) }
        return describe(correction, axis: session.axis)
    }

    private static func notInPass(_ axis: Axis) -> String {
        let kind = axis == .vertical ? "vertical" : "horizontal"
        return "Not in this pass: no \(kind) line in common with the reference.\nPress V to switch axis."
    }

    private static func describe(_ correction: Correction, axis: Axis) -> String {
        let coordinate = axis == .vertical ? "X" : "Y"
        let amount = correction.isAligned ? "0 pt, aligned" : "\(signed(correction.shift)) pt"
        let mismatch = correction.hasScaleMismatch ? scaleWarning(correction.disagreement) : ""
        return "Correction \(coordinate): \(amount)" + mismatch
    }

    private static func scaleWarning(_ disagreement: CGFloat) -> String {
        "\nLines disagree by \(Int(disagreement.rounded())) pt: the screens differ in physical size per point,"
            + "\nso the cursor can match at one position only."
    }

    private static func listed(_ corrections: [Correction], names: [DisplayID: String]) -> String {
        corrections
            .map { "\(names[$0.display] ?? "Display \($0.display)") \(signed($0.shift)) pt" }
            .joined(separator: ", ")
    }

    private static func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }

    private static func size(_ frame: CGRect) -> String { "\(Int(frame.width))x\(Int(frame.height))" }
}
