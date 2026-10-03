import CoreGraphics

public typealias DisplayID = UInt32

/// One active screen, with its frame in global display points (origin top-left, y grows downward).
public struct Display: Hashable, Sendable {
    public let id: DisplayID
    public let name: String
    public let frame: CGRect
    public let isMain: Bool
    /// Stable across reconnects and reboots, unlike `id`. Used to store calibrations.
    public let key: String
    /// Physical size the monitor reports, zero when unknown.
    public let millimetres: CGSize

    public init(id: DisplayID, name: String, frame: CGRect, isMain: Bool, key: String? = nil, millimetres: CGSize = .zero) {
        self.id = id
        self.name = name
        self.frame = frame
        self.isMain = isMain
        self.key = key ?? "display-\(id)"
        self.millimetres = millimetres
    }

    /// Points per millimetre along an axis, when the monitor reports its size.
    public func density(along axis: Axis) -> CGFloat? {
        let physical = axis == .vertical ? millimetres.width : millimetres.height
        return physical > 0 ? frame.length(along: axis) / physical : nil
    }
}

/// The boundary to the operating system's display arrangement.
public protocol DisplayArrangement {
    func activeDisplays() -> [Display]
    func moveDisplays(to origins: [DisplayID: CGPoint]) -> Result<Void, ArrangementError>
}

public enum ArrangementError: Error, Equatable {
    case configurationRefused(code: Int32)
    case commitRefused(code: Int32)
}
