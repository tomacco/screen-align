import AppKit

/// A user intent, decoded from a key press.
enum Command {
    case moveLine(by: CGFloat)
    case selectNextLine
    case addLine
    case removeLine
    case toggleAxis
    case toggleCursorLine
    case cycleBackdrop
    case apply
    case undo
    case quit

    init?(_ event: NSEvent) {
        guard let command = Command.decodeKey(event.keyCode, step: Command.step(event))
                ?? Command.decodeCharacter(event.charactersIgnoringModifiers?.lowercased()) else { return nil }
        self = command
    }
}

// MARK: - Leaves

extension Command {
    private static func step(_ event: NSEvent) -> CGFloat {
        event.modifierFlags.contains(.shift) ? 10 : 1
    }

    private static func decodeKey(_ code: UInt16, step: CGFloat) -> Command? {
        switch code {
        case 123, 126: return .moveLine(by: -step)   // left, up
        case 124, 125: return .moveLine(by: step)    // right, down
        case 48: return .selectNextLine              // tab
        case 36, 76: return .apply                   // return, enter
        case 51, 117: return .removeLine             // delete, forward delete
        case 53: return .quit                        // escape
        default: return nil
        }
    }

    private static func decodeCharacter(_ character: String?) -> Command? {
        switch character {
        case "n": return .addLine
        case "v": return .toggleAxis
        case "t": return .toggleCursorLine
        case "b": return .cycleBackdrop
        case "u": return .undo
        case "q": return .quit
        default: return nil
        }
    }
}
