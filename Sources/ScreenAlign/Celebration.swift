import AppKit
import ScreenAlignCore

/// The final screen: which edges the user has tried with the cursor.
@MainActor
final class Celebration {
    struct Edge {
        let from: Display
        let to: Display
        var crossed = false
    }

    private(set) var edges: [Edge]
    let onDone: () -> Void
    let onUndo: () -> Void

    init(hops: [Hop], onDone: @escaping () -> Void, onUndo: @escaping () -> Void) {
        self.edges = hops.map { Edge(from: $0.from, to: $0.to) }
        self.onDone = onDone
        self.onUndo = onUndo
    }

    var allCrossed: Bool { edges.allSatisfy(\.crossed) }

    /// Marks the edge between two screens as tried. Returns true the first time only.
    func check(_ a: DisplayID, _ b: DisplayID) -> Bool {
        guard let index = edges.firstIndex(where: { Set([$0.from.id, $0.to.id]) == Set([a, b]) }),
              !edges[index].crossed else { return false }
        edges[index].crossed = true
        return true
    }
}
