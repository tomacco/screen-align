// ScreenAlign: align the vertical offset of multiple displays by eye.
// Each screen shows the same set of horizontal lines. Move them until each line
// looks like one continuous physical line across all screens, then press Return:
// the display arrangement is written with CGCompleteDisplayConfiguration(.permanently),
// the same store System Settings > Displays > Arrange uses.

import Cocoa

// MARK: - Model

final class Model {
    // Line positions per display, in points from the top of that display.
    var lines: [CGDirectDisplayID: [CGFloat]] = [:]
    var lineCount = 1
    var sel: (display: CGDirectDisplayID, line: Int) = (CGMainDisplayID(), 0)
    var testMode = true
    var dim: CGFloat = 0.78
    var mouse = CGPoint.zero
    var status = "Drag a line or use arrow keys. Return applies."
    var backup: [CGDirectDisplayID: CGPoint]?

    var displays: [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var n: UInt32 = 0
        CGGetActiveDisplayList(16, &ids, &n)
        // Skip mirror slaves: they share a frame with their master.
        return ids.prefix(Int(n)).filter { CGDisplayMirrorsDisplay($0) == kCGNullDirectDisplay }
    }

    var reference: CGDirectDisplayID { CGMainDisplayID() }

    // Seed lines at the same global height on every display so an already aligned
    // arrangement starts at zero correction.
    func seed() {
        let ds = displays
        let top = ds.map { CGDisplayBounds($0).minY }.max() ?? 0
        let bottom = ds.map { CGDisplayBounds($0).maxY }.min() ?? 0
        for d in ds {
            let b = CGDisplayBounds(d)
            var ls = Array((lines[d] ?? []).prefix(lineCount))
            // Keep lines the user has placed; only add the missing ones.
            for k in ls.count..<lineCount {
                let f = CGFloat(k + 1) / CGFloat(lineCount + 1)
                let global = bottom > top ? top + f * (bottom - top) : b.minY + f * b.height
                ls.append(min(max(global - b.minY, 0), b.height - 1).rounded())
            }
            lines[d] = ls
        }
        if sel.line >= lineCount { sel.line = lineCount - 1 }
        if !ds.contains(sel.display) { sel.display = reference }
    }

    // Per-line vertical shift (points) needed so display d's lines meet the reference's.
    func deltas(_ d: CGDirectDisplayID) -> [CGFloat] {
        let r = reference, rb = CGDisplayBounds(r), db = CGDisplayBounds(d)
        guard let rl = lines[r], let dl = lines[d] else { return [] }
        return zip(rl, dl).map { (rb.minY + $0) - (db.minY + $1) }
    }

    func proposedShift(_ d: CGDirectDisplayID) -> Int {
        let ds = deltas(d)
        guard !ds.isEmpty else { return 0 }
        return Int((ds.reduce(0, +) / CGFloat(ds.count)).rounded())
    }

    func apply() {
        let ds = displays.filter { $0 != reference }
        let shifts = ds.map { ($0, proposedShift($0)) }.filter { $0.1 != 0 }
        guard !shifts.isEmpty else { status = "Already aligned. Nothing to write."; return }
        backup = Dictionary(uniqueKeysWithValues: displays.map { ($0, CGDisplayBounds($0).origin) })
        var cfg: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&cfg) == .success else { status = "Could not begin display configuration."; return }
        for (d, s) in shifts {
            let o = CGDisplayBounds(d).origin
            CGConfigureDisplayOrigin(cfg, d, Int32(o.x), Int32(o.y) + Int32(s))
        }
        let err = CGCompleteDisplayConfiguration(cfg, .permanently)
        status = err == .success
            ? "Applied: " + shifts.map { "\(name($0.0)) \($0.1 > 0 ? "+" : "")\($0.1) pt" }.joined(separator: ", ") + ". U undoes."
            : "Apply failed (CGError \(err.rawValue))."
    }

    func undo() {
        guard let b = backup else { status = "Nothing to undo."; return }
        var cfg: CGDisplayConfigRef?
        CGBeginDisplayConfiguration(&cfg)
        for (d, o) in b where displays.contains(d) { CGConfigureDisplayOrigin(cfg, d, Int32(o.x), Int32(o.y)) }
        let err = CGCompleteDisplayConfiguration(cfg, .permanently)
        status = err == .success ? "Restored previous arrangement." : "Undo failed (CGError \(err.rawValue))."
        backup = nil
    }

    func name(_ d: CGDirectDisplayID) -> String {
        NSScreen.screens.first { $0.displayID == d }?.localizedName ?? "Display \(d)"
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}

let model = Model()

// MARK: - View

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AlignView: NSView {
    let display: CGDirectDisplayID
    var dragging: Int?

    init(frame: NSRect, display: CGDirectDisplayID) {
        self.display = display
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }   // y grows downward, matching CG display space
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    static let palette: [NSColor] = [.systemRed, .systemGreen, .systemCyan, .systemYellow, .systemPink, .systemOrange]

    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0, alpha: model.dim).setFill()
        bounds.fill()
        let b = CGDisplayBounds(display)
        let hair = 1 / (window?.backingScaleFactor ?? 2)   // one device pixel

        for (k, y) in (model.lines[display] ?? []).enumerated() {
            let c = Self.palette[k % Self.palette.count]
            let selected = model.sel.display == display && model.sel.line == k
            if selected {
                c.withAlphaComponent(0.18).setFill()
                NSRect(x: 0, y: y - 6, width: bounds.width, height: 12).fill()
            }
            c.setFill()
            NSRect(x: 0, y: y, width: bounds.width, height: hair).fill()
            // Edge ticks make the line easy to find next to the bezel.
            NSRect(x: 0, y: y - 8, width: 3, height: 16 + hair).fill()
            NSRect(x: bounds.width - 3, y: y - 8, width: 3, height: 16 + hair).fill()
            label("\(k + 1)  y=\(Int(y))", at: NSPoint(x: bounds.midX - 40, y: y - 20), color: c)
        }

        if model.testMode {
            let my = model.mouse.y - b.minY
            if my >= 0 && my < b.height {
                let p = NSBezierPath()
                p.move(to: NSPoint(x: 0, y: my)); p.line(to: NSPoint(x: bounds.width, y: my))
                p.lineWidth = hair
                p.setLineDash([6, 4], count: 2, phase: 0)
                NSColor.white.withAlphaComponent(0.85).setStroke()
                p.stroke()
            }
        }
        drawHUD(b)
    }

    func drawHUD(_ b: CGRect) {
        let isRef = display == model.reference
        var text = "\(model.name(display))  \(Int(b.width))x\(Int(b.height)) pt @ (\(Int(b.minX)), \(Int(b.minY)))"
        if isRef {
            text += "\nREFERENCE display (stays fixed)"
        } else {
            let ds = model.deltas(display)
            let shift = model.proposedShift(display)
            text += "\nCorrection: \(shift > 0 ? "+" : "")\(shift) pt" + (shift == 0 ? "  aligned" : "")
            if ds.count > 1, let lo = ds.min(), let hi = ds.max(), hi - lo >= 1 {
                text += String(format: "\nLines disagree by %.0f pt: physical scale differs between screens,\nso the cursor can match exactly at one height only.", hi - lo)
            }
        }
        text += """
        \n
        drag / ↑↓ move line (⇧ x10)   Tab next line   N add line   ⌫ remove line
        T cursor test line   B background   Return APPLY   U undo   Esc quit
        \(model.status)
        """
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.white,
        ]
        let s = NSAttributedString(string: text, attributes: attrs)
        let size = s.boundingRect(with: NSSize(width: 700, height: 400), options: .usesLineFragmentOrigin).size
        let box = NSRect(x: bounds.midX - size.width / 2 - 12, y: bounds.height - size.height - 60,
                         width: size.width + 24, height: size.height + 16)
        NSColor(white: 0.1, alpha: 0.9).setFill()
        NSBezierPath(roundedRect: box, xRadius: 8, yRadius: 8).fill()
        s.draw(with: box.insetBy(dx: 12, dy: 8), options: .usesLineFragmentOrigin)
    }

    func label(_ s: String, at p: NSPoint, color: NSColor) {
        NSAttributedString(string: s, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium), .foregroundColor: color,
        ]).draw(at: p)
    }

    // MARK: input

    func nearestLine(_ y: CGFloat) -> Int {
        let ls = model.lines[display] ?? []
        return ls.indices.min { abs(ls[$0] - y) < abs(ls[$1] - y) } ?? 0
    }

    override func mouseDown(with e: NSEvent) {
        window?.makeKey()
        let y = convert(e.locationInWindow, from: nil).y
        let k = nearestLine(y)
        model.sel = (display, k)
        dragging = abs((model.lines[display]?[k] ?? y) - y) < 24 ? k : nil
        redrawAll()
    }

    override func mouseDragged(with e: NSEvent) {
        guard let k = dragging else { return }
        let y = convert(e.locationInWindow, from: nil).y
        model.lines[display]?[k] = min(max(y.rounded(), 0), bounds.height - 1)
        redrawAll()
    }

    override func mouseUp(with e: NSEvent) { dragging = nil }

    override func keyDown(with e: NSEvent) {
        let step: CGFloat = e.modifierFlags.contains(.shift) ? 10 : 1
        let d = model.sel.display, k = model.sel.line
        switch e.keyCode {
        case 126: move(d, k, -step)                       // up
        case 125: move(d, k, step)                        // down
        case 48: cycleSelection()                         // tab
        case 36, 76: model.apply()                        // return / enter
        case 53: NSApp.terminate(nil)                     // esc
        case 51, 117:                                     // delete
            if model.lineCount > 1 {
                for id in model.lines.keys { model.lines[id]?.remove(at: k) }
                model.lineCount -= 1
                model.sel.line = min(k, model.lineCount - 1)
            }
        default:
            switch e.charactersIgnoringModifiers?.lowercased() {
            case "n": model.lineCount += 1; model.seed(); model.sel.line = model.lineCount - 1
            case "t": model.testMode.toggle()
            case "b": model.dim = model.dim > 0.9 ? 0.5 : (model.dim > 0.6 ? 1.0 : 0.78)
            case "u": model.undo()
            case "q": NSApp.terminate(nil)
            default: super.keyDown(with: e)
            }
        }
        redrawAll()
    }

    func move(_ d: CGDirectDisplayID, _ k: Int, _ by: CGFloat) {
        guard let y = model.lines[d]?[k] else { return }
        model.lines[d]?[k] = min(max(y + by, 0), CGDisplayBounds(d).height - 1)
    }

    func cycleSelection() {
        let ds = model.displays
        guard let i = ds.firstIndex(of: model.sel.display) else { return }
        if model.sel.line + 1 < model.lineCount { model.sel.line += 1 }
        else { model.sel = (ds[(i + 1) % ds.count], 0) }
        // Follow the selection with keyboard focus.
        Controller.shared.windows.first { ($0.contentView as? AlignView)?.display == model.sel.display }?.makeKey()
    }
}

func redrawAll() { Controller.shared.windows.forEach { $0.contentView?.needsDisplay = true } }

// MARK: - Controller

final class Controller: NSObject, NSApplicationDelegate {
    static let shared = Controller()
    var windows: [NSWindow] = []
    var lastMouse = CGPoint(x: -1, y: -1)

    func applicationDidFinishLaunching(_ n: Notification) {
        model.seed()
        rebuild()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            model.seed(); self?.rebuild()
        }
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            let p = CGEvent(source: nil)?.location ?? .zero
            if model.testMode && p != self?.lastMouse { self?.lastMouse = p; model.mouse = p; redrawAll() }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    // Recreate one overlay per screen; called at launch and whenever the arrangement changes.
    func rebuild() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.filter { model.displays.contains($0.displayID) }.map { screen in
            let w = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.setFrame(screen.frame, display: false)
            w.level = .screenSaver
            w.isOpaque = false
            w.backgroundColor = .clear
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            w.isReleasedWhenClosed = false
            w.contentView = AlignView(frame: NSRect(origin: .zero, size: screen.frame.size), display: screen.displayID)
            w.orderFrontRegardless()
            return w
        }
        (windows.first { ($0.contentView as? AlignView)?.display == model.sel.display } ?? windows.first)?.makeKey()
        redrawAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.delegate = Controller.shared
app.run()
