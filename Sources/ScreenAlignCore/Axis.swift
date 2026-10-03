import CoreGraphics

/// The direction the alignment lines run in.
/// Horizontal lines align screens placed side by side (corrects Y).
/// Vertical lines align screens stacked on top of each other (corrects X).
public enum Axis: Sendable {
    case horizontal
    case vertical

    public var toggled: Axis { self == .horizontal ? .vertical : .horizontal }

    /// Picks the axis the arrangement suggests: stacked screens span more height than width.
    public static func suggested(for displays: [Display]) -> Axis {
        let frames = displays.map(\.frame)
        let union = frames.reduce(CGRect.null) { $0.union($1) }
        let tallest = frames.map(\.height).max() ?? 1
        let widest = frames.map(\.width).max() ?? 1
        return union.height / tallest > union.width / widest ? .vertical : .horizontal
    }
}

extension CGRect {
    /// Start of the rect along the axis a line moves on.
    public func start(along axis: Axis) -> CGFloat { axis == .vertical ? minX : minY }
    public func end(along axis: Axis) -> CGFloat { axis == .vertical ? maxX : maxY }
    public func length(along axis: Axis) -> CGFloat { axis == .vertical ? width : height }
}

extension CGPoint {
    public func position(along axis: Axis) -> CGFloat { axis == .vertical ? x : y }
}
