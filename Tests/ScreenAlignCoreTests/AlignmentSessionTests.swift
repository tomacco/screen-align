import CoreGraphics
import Testing
@testable import ScreenAlignCore

@Suite struct AlignmentSessionTests {
    @Test func seededLines_needNoCorrection_whenArrangementIsUntouched() {
        let session = AlignmentSession(displays: [laptop, besideLeft])

        let corrections = session.pendingCorrections()

        #expect(corrections.isEmpty)
    }

    @Test func movingSecondaryLineDown_asksToMoveThatDisplayUp() {
        let session = AlignmentSession(displays: [laptop, besideLeft])
        session.select(line(besideLeft))

        session.moveSelected(by: 10)

        #expect(session.correction(for: besideLeft)?.shift == -10)
    }

    @Test func suggestedAxis_isVertical_whenScreensAreStacked() {
        let axis = Axis.suggested(for: [laptop, above])

        #expect(axis == .vertical)
    }

    @Test func horizontalPass_leavesOutDisplaysStackedAboveTheReference() {
        let session = AlignmentSession(displays: [laptop, besideLeft, above])

        let participants = session.participants.map(\.id)

        #expect(participants == [laptop.id, besideLeft.id])
    }

    @Test func twoLinesThatDisagree_reportAScaleMismatch() {
        let session = AlignmentSession(displays: [laptop, besideLeft])
        session.addLine()
        session.select(line(besideLeft, 1))

        session.moveSelected(by: 4)

        #expect(session.correction(for: besideLeft)?.hasScaleMismatch == true)
    }

    @Test func addingALine_keepsLinesTheUserAlreadyPlaced() {
        let session = AlignmentSession(displays: [laptop, besideLeft])
        session.select(line(besideLeft))
        session.moveSelected(by: 7)
        let placed = session.lines(on: besideLeft.id)[0]

        session.addLine()

        #expect(session.lines(on: besideLeft.id)[0] == placed)
    }

    @Test func lines_stayInsideTheirDisplay() {
        let session = AlignmentSession(displays: [laptop, besideLeft])

        session.place(line(laptop), at: 5000)

        #expect(session.lines(on: laptop.id)[0] == laptop.frame.height - 1)
    }
}
