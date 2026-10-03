import CoreGraphics

/// What the user has placed so far: lines per display, the current selection and the axis.
/// Line positions are in points from the top (or left, for vertical lines) of their display.
public final class AlignmentSession {
    public private(set) var axis: Axis
    public private(set) var lineCount = 1
    public private(set) var selection: LineSelection
    private var lines: [DisplayID: [CGFloat]] = [:]
    private var displays: [Display]

    public init(displays: [Display]) {
        self.displays = displays
        self.axis = Axis.suggested(for: displays)
        self.selection = LineSelection(display: displays.first { $0.isMain }?.id ?? 0, line: 0)
        seedMissingLines()
    }

    public var reference: Display? { displays.first { $0.isMain } }

    public var participants: [Display] {
        guard let reference else { return [] }
        return displays.filter { $0.id == reference.id || sharesLine(with: reference, $0) }
    }

    public func lines(on display: DisplayID) -> [CGFloat] { lines[display] ?? [] }

    public func update(displays: [Display]) {
        self.displays = displays
        seedMissingLines()
        keepSelectionOnScreen()
    }

    public func toggleAxis() {
        axis = axis.toggled
        lines = [:]
        selection = LineSelection(display: reference?.id ?? 0, line: 0)
        seedMissingLines()
    }

    public func addLine() {
        lineCount += 1
        seedMissingLines()
        selection = LineSelection(display: selection.display, line: lineCount - 1)
    }

    public func removeSelectedLine() {
        guard lineCount > 1 else { return }
        removeLine(at: selection.line)
        selection = LineSelection(display: selection.display, line: min(selection.line, lineCount - 1))
    }

    public func select(_ newSelection: LineSelection) {
        guard isPlaced(newSelection) else { return }
        selection = newSelection
    }

    public func selectNext() {
        selection = nextSelection()
    }

    public func moveSelected(by points: CGFloat) {
        let current = lines(on: selection.display)[safe: selection.line] ?? 0
        place(selection, at: current + points)
    }

    public func place(_ target: LineSelection, at position: CGFloat) {
        guard isPlaced(target), let display = participant(target.display) else { return }
        lines[target.display]?[target.line] = clamped(position.rounded(), to: display)
    }
}

public struct LineSelection: Hashable, Sendable {
    public let display: DisplayID
    public let line: Int

    public init(display: DisplayID, line: Int) {
        self.display = display
        self.line = line
    }
}

// MARK: - Leaves

extension AlignmentSession {
    private func sharesLine(with reference: Display, _ display: Display) -> Bool {
        display.frame.start(along: axis) < reference.frame.end(along: axis)
            && display.frame.end(along: axis) > reference.frame.start(along: axis)
    }

    /// Seeds new lines at the same global position on every participant, so a correct arrangement
    /// starts at zero correction. Lines the user placed are kept.
    private func seedMissingLines() {
        let shared = sharedSpan()
        for display in participants {
            var placed = Array(lines(on: display.id).prefix(lineCount))
            for index in placed.count..<lineCount {
                placed.append(seedPosition(index, on: display, shared: shared))
            }
            lines[display.id] = placed
        }
    }

    private func sharedSpan() -> ClosedRange<CGFloat>? {
        let frames = participants.map(\.frame)
        let start = frames.map { $0.start(along: axis) }.max() ?? 0
        let end = frames.map { $0.end(along: axis) }.min() ?? 0
        return start < end ? start...end : nil
    }

    private func seedPosition(_ index: Int, on display: Display, shared: ClosedRange<CGFloat>?) -> CGFloat {
        let fraction = CGFloat(index + 1) / CGFloat(lineCount + 1)
        let span = shared ?? display.frame.start(along: axis)...display.frame.end(along: axis)
        let global = span.lowerBound + fraction * (span.upperBound - span.lowerBound)
        return clamped((global - display.frame.start(along: axis)).rounded(), to: display)
    }

    private func clamped(_ position: CGFloat, to display: Display) -> CGFloat {
        min(max(position, 0), display.frame.length(along: axis) - 1)
    }

    private func removeLine(at index: Int) {
        for id in lines.keys { lines[id]?.remove(at: index) }
        lineCount -= 1
    }

    private func nextSelection() -> LineSelection {
        let ids = participants.map(\.id)
        guard let current = ids.firstIndex(of: selection.display) else { return selection }
        if selection.line + 1 < lineCount {
            return LineSelection(display: selection.display, line: selection.line + 1)
        }
        return LineSelection(display: ids[(current + 1) % ids.count], line: 0)
    }

    private func keepSelectionOnScreen() {
        guard !isPlaced(selection) else { return }
        selection = LineSelection(display: reference?.id ?? 0, line: 0)
    }

    private func isPlaced(_ target: LineSelection) -> Bool {
        lines(on: target.display).indices.contains(target.line)
    }

    private func participant(_ id: DisplayID) -> Display? {
        participants.first { $0.id == id }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
