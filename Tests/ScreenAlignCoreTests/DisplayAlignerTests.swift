import CoreGraphics
import Testing
@testable import ScreenAlignCore

@Suite struct DisplayAlignerTests {
    @Test func apply_writesTheShiftToY_forHorizontalLines() {
        let arrangement = FakeArrangement([laptop, besideLeft])
        let session = AlignmentSession(displays: arrangement.displays)
        session.select(line(besideLeft))
        session.moveSelected(by: 10)

        let outcome = DisplayAligner(arrangement: arrangement).apply(session)

        #expect(outcome == .applied([Correction(display: besideLeft.id, shift: -10, disagreement: 0)]))
        #expect(arrangement.writes == [[besideLeft.id: CGPoint(x: -2560, y: -425)]])
    }

    @Test func apply_writesTheShiftToX_forVerticalLines() {
        let arrangement = FakeArrangement([laptop, above])
        let session = AlignmentSession(displays: arrangement.displays)
        session.select(line(above))
        session.moveSelected(by: -20)

        _ = DisplayAligner(arrangement: arrangement).apply(session)

        #expect(arrangement.writes == [[above.id: CGPoint(x: -280, y: -1440)]])
    }

    @Test func apply_writesNothing_whenAlreadyAligned() {
        let arrangement = FakeArrangement([laptop, besideLeft])

        let outcome = DisplayAligner(arrangement: arrangement).apply(AlignmentSession(displays: arrangement.displays))

        #expect(outcome == .alreadyAligned)
        #expect(arrangement.writes.isEmpty)
    }

    @Test func undo_restoresThePreviousOrigins() {
        let arrangement = FakeArrangement([laptop, besideLeft])
        let session = AlignmentSession(displays: arrangement.displays)
        let aligner = DisplayAligner(arrangement: arrangement)
        session.select(line(besideLeft))
        session.moveSelected(by: 10)
        _ = aligner.apply(session)

        let outcome = aligner.undo()

        #expect(outcome == .restored)
        #expect(arrangement.displays == [laptop, besideLeft])
    }

    @Test func refusedWrite_isReported_andLeavesNothingToUndo() {
        let arrangement = FakeArrangement([laptop, besideLeft])
        arrangement.refusal = .commitRefused(code: 1001)
        let session = AlignmentSession(displays: arrangement.displays)
        let aligner = DisplayAligner(arrangement: arrangement)
        session.select(line(besideLeft))
        session.moveSelected(by: 10)

        let outcome = aligner.apply(session)

        #expect(outcome == .failed(.commitRefused(code: 1001)))
        #expect(aligner.undo() == .nothingToUndo)
    }
}
