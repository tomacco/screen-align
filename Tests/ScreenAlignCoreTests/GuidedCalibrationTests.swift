import CoreGraphics
import Testing
@testable import ScreenAlignCore

@Suite struct TopologyTests {
    @Test func sideBySideScreens_areVisitedLeftToRight() {
        let hops = Topology.hops([macBook, midDell, leftDell])

        #expect(hops.map { [$0.from.key, $0.to.key] } == [["dell-left", "dell-mid"], ["dell-mid", "macbook"]])
        #expect(hops.allSatisfy { $0.axis == .horizontal })
    }

    @Test func stackedScreens_shareAVerticalAxis() {
        let hops = Topology.hops([laptop, above])

        #expect(hops.map(\.axis) == [.vertical])
    }
}

@Suite struct EdgeCalibrationTests {
    private let hop = Hop(from: midDell, to: macBook, axis: .horizontal)

    @Test func twoLines_giveScaleAndOffset() throws {
        let calibration = try EdgeCalibration.solve(hop, samples: [LineSample(from: 100, to: 50), LineSample(from: 1100, to: 1240)]).get()

        #expect(calibration.scale == 1.19)
        #expect(calibration.map(100) == 50)
    }

    @Test func linesTooCloseTogether_areRejected() {
        let result = EdgeCalibration.solve(hop, samples: [LineSample(from: 100, to: 50), LineSample(from: 110, to: 62)])

        #expect(result == .failure(.linesTooClose))
    }

    @Test func reversed_mapsBackToTheStart() throws {
        let calibration = try EdgeCalibration.solve(hop, samples: [LineSample(from: 100, to: 50), LineSample(from: 1100, to: 1240)]).get()

        #expect(abs(calibration.reversed.map(calibration.map(700)) - 700) < 0.001)
    }
}

@Suite struct CalibrationWizardTests {
    @Test func wizard_takesTwoLinesPerSharedEdge() {
        let wizard = CalibrationWizard(displays: [leftDell, midDell, macBook])

        #expect(wizard.stepCount == 4)
        #expect(wizard.step?.hop.from.key == "dell-left")
    }

    @Test func carefulUser_endsWithThePhysicalScale() {
        let calibrations = calibratedDesk()

        #expect(calibrations.count == 2)
        #expect(abs(calibrations[1].scale - 5.02 / 4.23) < 0.01)
    }

    @Test func lineMissingTheNextScreen_movesTheFixedLineInward() {
        let wizard = CalibrationWizard(displays: [midDell, macBook])
        let before = wizard.step?.anchor ?? 0

        wizard.reportLineMissesScreen()

        #expect((wizard.step?.anchor ?? 0) > before)
    }

    @Test func goingBack_reopensTheFirstLine() {
        let wizard = CalibrationWizard(displays: [midDell, macBook])
        wizard.moveCandidate(by: 33)
        let placed = wizard.step?.candidate
        _ = wizard.confirm()

        wizard.goBack()

        #expect(wizard.step?.line == 0)
        #expect(wizard.step?.candidate == placed)
    }
}

@Suite struct PhysicalCrossingTests {
    @Test func plannedArrangement_needsNoCorrection_atTheAlignedHeight() throws {
        let calibrations = calibratedDesk()
        let origins = ArrangementPlanner.origins(for: [leftDell, midDell, macBook], calibrations: calibrations)
        let movedDell = try #require(moved(midDell, to: origins[midDell.id]))
        let movedMac = try #require(moved(macBook, to: origins[macBook.id]))
        let pivot = try #require(calibrations[1].sharedSpan).midPoint
        let corrector = CrossingCorrector(displays: [movedDell, movedMac], calibrations: calibrations)

        let crossingAtPivot = CGPoint(x: 5, y: movedDell.frame.minY + pivot)

        #expect(corrector.correctedLocation(from: CGPoint(x: -5, y: crossingAtPivot.y), to: crossingAtPivot) == nil)
    }

    @Test func crossingFarFromThePivot_landsWhereThePathPhysicallyContinues() throws {
        let calibrations = calibratedDesk()
        let corrector = CrossingCorrector(displays: [midDell, macBook], calibrations: calibrations)
        let dellLocal: CGFloat = 900

        let corrected = try #require(corrector.correctedLocation(
            from: CGPoint(x: -3, y: midDell.frame.minY + dellLocal),
            to: CGPoint(x: 2, y: midDell.frame.minY + dellLocal)))

        let expected = desk[2].local(at: desk[1].millimetres(at: dellLocal))
        #expect(abs((corrected.y - macBook.frame.minY) - expected) <= 1)
    }

    @Test func resolutionChange_turnsCorrectionOff() {
        let rescaled = Display(id: macBook.id, name: "MacBook", frame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
                               isMain: true, key: "macbook")
        let corrector = CrossingCorrector(displays: [midDell, rescaled], calibrations: calibratedDesk())

        #expect(corrector.correctedLocation(from: CGPoint(x: -3, y: 600), to: CGPoint(x: 2, y: 600)) == nil)
    }

    private func moved(_ display: Display, to origin: CGPoint?) -> Display? {
        origin.map { Display(id: display.id, name: display.name, frame: CGRect(origin: $0, size: display.frame.size),
                             isMain: display.isMain, key: display.key) }
    }
}

extension ClosedRange where Bound == CGFloat {
    var midPoint: CGFloat { (lowerBound + upperBound) / 2 }
}

@Suite struct LineOutsideScreenTests {
    /// Why the "line misses this screen" key exists: today's arrangement places the first line
    /// inside the laptop, while physically it passes above the laptop's top edge.
    @Test func firstLine_isPredictedInside_butPhysicallyPassesAboveTheLaptop() throws {
        let step = try #require(CalibrationWizard(displays: [midDell, macBook]).step)

        #expect(step.candidateAtEdge == false)
        #expect(truthfulCandidate(for: step) < 0)
    }
}
