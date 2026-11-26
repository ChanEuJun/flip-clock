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

@MainActor
final class AppState: ObservableObject {
    @Published var mode: Mode = .clock
    @Published private(set) var hh = "00"
    @Published private(set) var mm = "00"
    @Published private(set) var remaining: Int
    @Published private(set) var phase: Phase = .idle
    @Published var presetMinutes: Int {
        didSet {
            UserDefaults.standard.set(presetMinutes, forKey: "presetMinutes")
            if phase == .idle { remaining = presetMinutes * 60 }
        }
    }
    @Published var keepOnTop = false {
        didSet { NSApp.windows.forEach { $0.level = keepOnTop ? .floating : .normal } }
    }

    let store = SessionStore()
    private var endDate: Date?
    private var plannedSeconds = 0
    private var sessionStart = Date()
    private var ticker: Timer?

    init() {
        let saved = UserDefaults.standard.integer(forKey: "presetMinutes")
        let preset = saved > 0 ? saved : 25
        presetMinutes = preset
        remaining = preset * 60
        updateClock()
        startTicker()
    }

    // MARK: Ticking — one 1 Hz timer aligned to the second, with tolerance so macOS can coalesce wakeups.

    private func startTicker() {
        let next = Date(timeIntervalSinceReferenceDate: ceil(Date().timeIntervalSinceReferenceDate))
        let t = Timer(fire: next, interval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.15
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
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let h = String(format: "%02d", c.hour ?? 0), m = String(format: "%02d", c.minute ?? 0)
        // Only publish on change so SwiftUI doesn't re-render every second.
        if h != hh { hh = h }
        if m != mm { mm = m }
    }

    // MARK: Timer controls

    func toggle() {
        switch phase {
        case .idle:
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
        remaining = presetMinutes * 60
    }

    func adjust(by delta: Int) {
        guard phase == .idle else { return }
        presetMinutes = min(95, max(5, presetMinutes + delta))
    }

    // MARK: Window

    /// Snap the window to a full-height quarter-width column on the given side of its screen.
    func snap(right: Bool) {
        guard let w = NSApp.keyWindow ?? NSApp.windows.first, let screen = w.screen ?? NSScreen.main else { return }
        let f = screen.visibleFrame
        let width = (f.width / 4).rounded()
        w.setFrame(NSRect(x: right ? f.maxX - width : f.minX, y: f.minY, width: width, height: f.height),
                   display: true, animate: true)
    }
}
