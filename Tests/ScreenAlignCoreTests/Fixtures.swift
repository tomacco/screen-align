import CoreGraphics
@testable import ScreenAlignCore

final class FakeArrangement: DisplayArrangement {
    private(set) var displays: [Display]
    private(set) var writes: [[DisplayID: CGPoint]] = []
    var refusal: ArrangementError?

    init(_ displays: [Display]) {
        self.displays = displays
    }

    func activeDisplays() -> [Display] { displays }

    func moveDisplays(to origins: [DisplayID: CGPoint]) -> Result<Void, ArrangementError> {
        if let refusal { return .failure(refusal) }
        writes.append(origins)
        displays = displays.map { moved($0, to: origins[$0.id]) }
        return .success(())
    }

    private func moved(_ display: Display, to origin: CGPoint?) -> Display {
        guard let origin else { return display }
        return Display(id: display.id, name: display.name, frame: CGRect(origin: origin, size: display.frame.size),
                       isMain: display.isMain)
    }
}

let laptop = Display(id: 1, name: "Laptop", frame: CGRect(x: 0, y: 0, width: 1512, height: 982), isMain: true)
let besideLeft = Display(id: 2, name: "Beside", frame: CGRect(x: -2560, y: -415, width: 2560, height: 1440), isMain: false)
let above = Display(id: 3, name: "Above", frame: CGRect(x: -300, y: -1440, width: 2560, height: 1440), isMain: false)

func line(_ display: Display, _ index: Int = 0) -> LineSelection {
    LineSelection(display: display.id, line: index)
}

// A desk like the one this was built on: two 27" screens side by side, a 14" laptop to the right.
// Physical truth: points per millimetre and how far below the left screen's top edge each screen starts.
struct PhysicalScreen {
    let display: Display
    let pointsPerMillimetre: CGFloat
    let topMillimetres: CGFloat

    func millimetres(at local: CGFloat) -> CGFloat { topMillimetres + local / pointsPerMillimetre }
    func local(at millimetres: CGFloat) -> CGFloat { (millimetres - topMillimetres) * pointsPerMillimetre }
}

let leftDell = Display(id: 10, name: "Left", frame: CGRect(x: -5120, y: -186, width: 2560, height: 1440), isMain: false, key: "dell-left")
let midDell = Display(id: 11, name: "Middle", frame: CGRect(x: -2560, y: -186, width: 2560, height: 1440), isMain: false, key: "dell-mid")
let macBook = Display(id: 12, name: "MacBook", frame: CGRect(x: 0, y: 0, width: 1512, height: 982), isMain: true, key: "macbook")

let desk = [
    PhysicalScreen(display: leftDell, pointsPerMillimetre: 4.23, topMillimetres: 0),
    PhysicalScreen(display: midDell, pointsPerMillimetre: 4.23, topMillimetres: 3),
    PhysicalScreen(display: macBook, pointsPerMillimetre: 5.02, topMillimetres: 110),
]

func physical(_ display: Display) -> PhysicalScreen? { desk.first { $0.display.id == display.id } }

/// The line a careful user places: the one that physically continues the fixed line.
func truthfulCandidate(for step: WizardStep) -> CGFloat {
    guard let from = physical(step.hop.from), let to = physical(step.hop.to) else { return step.candidate }
    return to.local(at: from.millimetres(at: step.anchor))
}

func calibratedDesk() -> [EdgeCalibration] {
    let wizard = CalibrationWizard(displays: [leftDell, midDell, macBook])
    while let step = wizard.step {
        let candidate = truthfulCandidate(for: step)
        if (0..<step.hop.to.frame.length(along: step.hop.axis)).contains(candidate) {
            wizard.placeCandidate(at: candidate)
            _ = wizard.confirm()
        } else {
            wizard.reportLineMissesScreen()
        }
    }
    return wizard.calibrations
}
