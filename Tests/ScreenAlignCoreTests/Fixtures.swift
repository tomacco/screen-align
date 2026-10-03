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
