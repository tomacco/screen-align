import AppKit
import ScreenAlignCore

extension AlignmentView {
    private static let grabDistance: CGFloat = 24

    func position(of event: NSEvent) -> CGFloat {
        convert(event.locationInWindow, from: nil).position(along: state.session.axis)
    }

    func grabNearestLine(at position: CGFloat) {
        guard let nearest = nearestLine(to: position) else { return }
        state.session.select(LineSelection(display: displayID, line: nearest.index))
        draggedLine = abs(nearest.position - position) < Self.grabDistance ? nearest.index : nil
    }

    func dragSelectedLine(to position: CGFloat) {
        guard let line = draggedLine else { return }
        state.session.place(LineSelection(display: displayID, line: line), at: position)
    }

    private func nearestLine(to position: CGFloat) -> (index: Int, position: CGFloat)? {
        state.session.lines(on: displayID)
            .enumerated()
            .min { abs($0.element - position) < abs($1.element - position) }
            .map { ($0.offset, $0.element) }
    }
}
