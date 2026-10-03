import AppKit
import ScreenAlignCore

/// Everything the overlays draw from. Owned by the controller, read by every view.
@MainActor
final class AppState {
    let session: AlignmentSession
    let aligner: DisplayAligner
    let arrangement: DisplayArrangement
    var status = "Drag a line or use the arrow keys. Return applies."
    var showsCursorLine = true
    var backdrop = Backdrop.dim
    var cursor = CGPoint.zero

    init(arrangement: DisplayArrangement) {
        self.arrangement = arrangement
        self.session = AlignmentSession(displays: arrangement.activeDisplays())
        self.aligner = DisplayAligner(arrangement: arrangement)
    }

    var displays: [Display] { arrangement.activeDisplays() }

    func display(_ id: DisplayID) -> Display? { displays.first { $0.id == id } }

    func displayNames() -> [DisplayID: String] {
        Dictionary(uniqueKeysWithValues: displays.map { ($0.id, $0.name) })
    }
}

enum Backdrop: CaseIterable {
    case dim, light, solid

    var opacity: CGFloat {
        switch self {
        case .dim: return 0.78
        case .light: return 0.5
        case .solid: return 1
        }
    }

    var next: Backdrop {
        let all = Backdrop.allCases
        return all[((all.firstIndex(of: self) ?? 0) + 1) % all.count]
    }
}
