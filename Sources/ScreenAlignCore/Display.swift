import CoreGraphics

public typealias DisplayID = UInt32

/// One active screen, with its frame in global display points (origin top-left, y grows downward).
public struct Display: Hashable, Sendable {
    public let id: DisplayID
    public let name: String
    public let frame: CGRect
    public let isMain: Bool

    public init(id: DisplayID, name: String, frame: CGRect, isMain: Bool) {
        self.id = id
        self.name = name
        self.frame = frame
        self.isMain = isMain
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
