import Foundation

struct Session: Codable, Identifiable {
    var id = UUID()
    let start: Date
    let minutes: Double
    let completed: Bool
}

struct DayTotal {
    var minutes: Double = 0
    var sessions: Int = 0  // completed sessions only
}

/// Persists sessions to ~/Library/Application Support/FlipFocus/sessions.json.
/// Written only when a session ends, so disk I/O is negligible.
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var byDay: [Date: DayTotal] = [:]
    private let url: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FlipFocus", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("sessions.json")
        if let data = try? Data(contentsOf: url),
           let decoded = try? Self.decoder.decode([Session].self, from: data) {
            sessions = decoded
        }
        rebuild()
    }

    func add(_ s: Session) {
        sessions.append(s)
        rebuild()
        if let data = try? Self.encoder.encode(sessions) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func total(for day: Date) -> DayTotal {
        byDay[Calendar.current.startOfDay(for: day)] ?? DayTotal()
    }

    /// Consecutive days with focus time, ending today (or yesterday if today is still empty).
    var streak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        if (byDay[day]?.minutes ?? 0) == 0 { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var n = 0
        while (byDay[day]?.minutes ?? 0) > 0 {
            n += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return n
    }

    private func rebuild() {
        let cal = Calendar.current
        var m: [Date: DayTotal] = [:]
        for s in sessions {
            let d = cal.startOfDay(for: s.start)
            m[d, default: DayTotal()].minutes += s.minutes
            if s.completed { m[d, default: DayTotal()].sessions += 1 }
        }
        byDay = m
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = .prettyPrinted; return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()
}
