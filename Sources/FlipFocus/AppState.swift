import AppKit
import SwiftUI

enum Mode: Int, CaseIterable {
    case clock, timer, stats
    var symbol: String {
        switch self {
        case .clock: "clock"
        case .timer: "timer"
        case .stats: "square.grid.3x3.fill"
        }
    }
}

enum Phase { case idle, running, paused }

/// Which row of the timer is being typed into.
enum Field: Int, CaseIterable { case hours, minutes, seconds }

@MainActor
final class AppState: ObservableObject {
    @Published var mode: Mode = .clock {
        didSet { if mode != .timer { commitEdit() } }
    }
    /// Wall clock as ["HH", "MM", "SS"]; each entry only republished when it changes.
    @Published private(set) var clock = ["00", "00", "00"]
    @Published private(set) var remaining: Int
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var presetSeconds: Int {
        didSet {
            UserDefaults.standard.set(presetSeconds, forKey: "presetSeconds")
            if phase == .idle { remaining = presetSeconds }
        }
    }
    @Published private(set) var editing: Field?
    @Published private(set) var buffer = ""
    @Published var keepOnTop = false {
        didSet { NSApp.windows.forEach { $0.level = keepOnTop ? .floating : .normal } }
    }

    let store = SessionStore()
    private var endDate: Date?
    private var plannedSeconds = 0
    private var sessionStart = Date()
    private var ticker: Timer?
    private var keyMonitor: Any?

    init() {
        let d = UserDefaults.standard
        var preset = d.integer(forKey: "presetSeconds")
        if preset <= 0 { preset = d.integer(forKey: "presetMinutes") * 60 }  // migrate v0.1 setting
        if preset <= 0 { preset = 25 * 60 }
        presetSeconds = preset
        remaining = preset
        updateClock()
        startTicker()
        installKeyMonitor()
    }

    // MARK: Ticking — one 1 Hz timer aligned to the second, with tolerance so macOS can coalesce wakeups.

    private func startTicker() {
        let next = Date(timeIntervalSinceReferenceDate: ceil(Date().timeIntervalSinceReferenceDate))
        let t = Timer(fire: next, interval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func tick() {
        updateClock()
        guard phase == .running, let end = endDate else { return }
        let r = max(0, Int(ceil(end.timeIntervalSinceNow - 0.05)))
        if r != remaining { remaining = r }
        if r == 0 { complete() }
    }

    private func updateClock() {
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        let next = [c.hour ?? 0, c.minute ?? 0, c.second ?? 0].map { String(format: "%02d", $0) }
        if next != clock { clock = next }
    }

    // MARK: Timer display

    /// Timer as ["HH", "MM", "SS"], with the row being typed into showing the typed digits.
    var timerDigits: [String] {
        let r = remaining
        var parts = [r / 3600, (r % 3600) / 60, r % 60].map { String(format: "%02d", $0) }
        if let f = editing, !buffer.isEmpty {
            parts[f.rawValue] = String(repeating: "0", count: 2 - buffer.count) + buffer
        }
        return parts
    }

    // MARK: Timer controls

    func toggle() {
        commitEdit()
        switch phase {
        case .idle:
            guard remaining > 0 else { return }
            plannedSeconds = remaining
            sessionStart = Date()
            fallthrough
        case .paused:
            endDate = Date().addingTimeInterval(TimeInterval(remaining))
            phase = .running
            mode = .timer
        case .running:
            endDate = nil
            phase = .paused
        }
    }

    /// Stops early; logs the partial minutes (≥1 min) toward focus time but not as a completed session.
    func cancel() {
        guard phase != .idle else { return }
        let focused = plannedSeconds - remaining
        if focused >= 60 {
            store.add(Session(start: sessionStart, minutes: Double(focused) / 60, completed: false))
        }
        reset()
    }

    private func complete() {
        store.add(Session(start: sessionStart, minutes: Double(plannedSeconds) / 60, completed: true))
        NSSound(named: "Glass")?.play()
        NSApp.requestUserAttention(.informationalRequest)
        reset()
    }

    private func reset() {
        phase = .idle
        endDate = nil
        remaining = presetSeconds
    }

    // MARK: Click-to-type entry

    /// Click on a row: start typing into it. Only while the timer is idle.
    func beginEdit(_ field: Field) {
        commitEdit()
        guard phase == .idle else { return }
        mode = .timer
        editing = field
        buffer = ""
    }

    func commitEdit() {
        guard let f = editing else { return }
        editing = nil
        defer { buffer = "" }
        guard let typed = Int(buffer) else { return }
        var h = presetSeconds / 3600, m = (presetSeconds % 3600) / 60, s = presetSeconds % 60
        switch f {
        case .hours: h = min(99, typed)
        case .minutes: m = min(59, typed)
        case .seconds: s = min(59, typed)
        }
        presetSeconds = h * 3600 + m * 60 + s
    }

    private func cancelEdit() {
        editing = nil
        buffer = ""
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let code = event.keyCode, chars = event.characters ?? "", flags = event.modifierFlags
            let consumed = MainActor.assumeIsolated { self?.handleKey(code: code, chars: chars, flags: flags) ?? false }
            return consumed ? nil : event
        }
    }

    /// Returns true if the key was used for timer entry.
    private func handleKey(code: UInt16, chars: String, flags: NSEvent.ModifierFlags) -> Bool {
        guard let field = editing, flags.intersection([.command, .control, .option]).isEmpty else { return false }
        switch code {
        case 36, 76: commitEdit()                     // return / enter
        case 53: cancelEdit()                         // escape
        case 51: buffer = String(buffer.dropLast())   // delete
        case 48:                                      // tab / shift-tab → next / previous row
            beginEdit(Field(rawValue: (field.rawValue + (flags.contains(.shift) ? 2 : 1)) % 3)!)
        default:
            if chars.count == 1, let c = chars.first, c.isASCII, c.isNumber {
                buffer = String((buffer + chars).suffix(2))
            }
        }
        return true
    }

    // MARK: Window

    /// Window width ÷ height, tuned by hand on a 1130pt-tall display (454 × 1130).
    /// Keeps the same balance of digits to negative space on any monitor.
    static let windowAspect: CGFloat = 454.0 / 1130.0

    private var mainWindow: NSWindow? {
        NSApp.windows.first { $0.isVisible && $0.canBecomeMain } ?? NSApp.windows.first
    }

    /// Full screen height at the default aspect, against the given edge (or whichever edge is nearer).
    func resetSize(right: Bool? = nil) {
        guard let w = mainWindow, let screen = w.screen ?? NSScreen.main else { return }
        let v = screen.visibleFrame
        let toRight = right ?? (w.frame.midX > v.midX)
        let width = (v.height * Self.windowAspect).rounded()
        w.setFrame(NSRect(x: toRight ? v.maxX - width : v.minX, y: v.minY, width: width, height: v.height),
                   display: true, animate: w.isVisible)
    }

    func snap(right: Bool) { resetSize(right: right) }

    /// Every launch: size to the screen the window opens on.
    func initialLayout() {
        DispatchQueue.main.async { [weak self] in self?.resetSize() }
    }
}
