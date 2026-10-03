import AppKit
import ScreenAlignCore

/// The live display arrangement, read and written through Core Graphics.
/// Writing with `.permanently` stores the result in the WindowServer display preferences,
/// so it survives logout and reboot.
struct SystemDisplayArrangement: DisplayArrangement {
    func activeDisplays() -> [Display] {
        activeDisplayIDs().filter(isNotMirrorCopy).map(makeDisplay)
    }

    func moveDisplays(to origins: [DisplayID: CGPoint]) -> Result<Void, ArrangementError> {
        var configuration: CGDisplayConfigRef?
        let began = CGBeginDisplayConfiguration(&configuration)
        guard began == .success else { return .failure(.configurationRefused(code: began.rawValue)) }

        stage(origins, in: configuration)
        return complete(configuration)
    }
}

// MARK: - Leaves

extension SystemDisplayArrangement {
    private func activeDisplayIDs() -> [DisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetActiveDisplayList(UInt32(ids.count), &ids, &count)
        return Array(ids.prefix(Int(count)))
    }

    private func isNotMirrorCopy(_ id: DisplayID) -> Bool {
        CGDisplayMirrorsDisplay(id) == kCGNullDirectDisplay
    }

    private func makeDisplay(_ id: DisplayID) -> Display {
        Display(id: id, name: screenName(id), frame: CGDisplayBounds(id), isMain: CGDisplayIsMain(id) != 0,
                key: stableKey(id))
    }

    private func screenName(_ id: DisplayID) -> String {
        NSScreen.screens.first { $0.displayID == id }?.localizedName ?? "Display \(id)"
    }

    /// Vendor, model and serial survive reconnects; the unit number separates twins without a serial.
    private func stableKey(_ id: DisplayID) -> String {
        let serial = CGDisplaySerialNumber(id)
        let base = "\(CGDisplayVendorNumber(id))-\(CGDisplayModelNumber(id))-\(serial)"
        return serial == 0 ? base + "-unit\(CGDisplayUnitNumber(id))" : base
    }

    private func stage(_ origins: [DisplayID: CGPoint], in configuration: CGDisplayConfigRef?) {
        for (id, origin) in origins {
            CGConfigureDisplayOrigin(configuration, id, Int32(origin.x), Int32(origin.y))
        }
    }

    private func complete(_ configuration: CGDisplayConfigRef?) -> Result<Void, ArrangementError> {
        let committed = CGCompleteDisplayConfiguration(configuration, .permanently)
        return committed == .success ? .success(()) : .failure(.commitRefused(code: committed.rawValue))
    }
}

extension NSScreen {
    var displayID: DisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
