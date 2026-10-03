import AppKit

/// A key press during guided calibration.
enum WizardCommand {
    case moveLine(by: CGFloat)
    case confirm
    case lineMissesScreen
    case back
    case switchToManual
    case cancel

    init?(_ event: NSEvent) {
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
        guard let command = WizardCommand.decodeKey(event.keyCode, step: step)
                ?? WizardCommand.decodeCharacter(event.charactersIgnoringModifiers?.lowercased()) else { return nil }
        self = command
    }
}

// MARK: - Leaves

extension WizardCommand {
    private static func decodeKey(_ code: UInt16, step: CGFloat) -> WizardCommand? {
        switch code {
        case 123, 126: return .moveLine(by: -step)   // left, up
        case 124, 125: return .moveLine(by: step)    // right, down
        case 36, 76: return .confirm                 // return, enter
        case 51, 117: return .back                   // delete, forward delete
        case 53: return .cancel                      // escape
        default: return nil
        }
    }

    private static func decodeCharacter(_ character: String?) -> WizardCommand? {
        switch character {
        case "x": return .lineMissesScreen
        case "m": return .switchToManual
        default: return nil
        }
    }
}
