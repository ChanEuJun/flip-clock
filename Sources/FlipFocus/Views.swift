import SwiftUI

let bg = Color(white: 0.125)
let labelGray = Color(white: 0.45)
let accent = Color(red: 1.0, green: 0.62, blue: 0.12)

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var hovering = false

    var body: some View {
        ZStack {
            bg.ignoresSafeArea().onTapGesture { state.commitEdit() }
            VStack(spacing: 0) {
                Group {
                    switch state.mode {
                    case .clock: ClockView()
                    case .timer: TimerView()
                    case .stats: StatsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                ModeBar().opacity(hovering ? 1 : 0.35)
            }
            .padding(.horizontal, 18)
            .padding(.top, 34)
            .padding(.bottom, 14)
        }
        .onHover { h in withAnimation(.easeOut(duration: 0.2)) { hovering = h } }
    }
}

// MARK: - Shared tile grid: HH / MM / SS stacked, filling the window height

struct TileGrid: View {
    let rows: [String]                 // ["HH", "MM", "SS"]
    var editing: Field? = nil
    var onTap: ((Field) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let gap = max(8, geo.size.width * 0.035)
            let tileW = max(10, (geo.size.width - gap) / 2)
            let tileH = max(10, min((geo.size.height - gap * 2) / 3, tileW * 1.7))
            VStack(spacing: gap) {
                ForEach(Field.allCases, id: \.self) { f in
                    row(rows[f.rawValue], field: f, w: tileW, h: tileH, gap: gap)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func row(_ digits: String, field: Field, w: CGFloat, h: CGFloat, gap: CGFloat) -> some View {
        HStack(spacing: gap) {
            ForEach(Array(digits.enumerated()), id: \.offset) { _, ch in
                FlipDigit(String(ch)).frame(width: w, height: h)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: w * 0.12, style: .continuous)
                .stroke(accent, lineWidth: 2)
                .padding(-4)
                .opacity(editing == field ? 1 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?(field) }
    }
}

// MARK: - Clock

struct ClockView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: SessionStore

    var body: some View {
        VStack(spacing: 10) {
            TileGrid(rows: state.clock) { state.beginEdit($0) }
            TodaySummary(total: store.total(for: Date()))
        }
    }
}

struct TodaySummary: View {
    let total: DayTotal
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<min(total.sessions, 12), id: \.self) { _ in
                Circle().fill(accent).frame(width: 7, height: 7)
            }
            if total.sessions == 0 { Circle().stroke(labelGray, lineWidth: 1).frame(width: 7, height: 7) }
            Text("\(total.sessions) session\(total.sessions == 1 ? "" : "s") · \(Int(total.minutes)) min today")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(labelGray)
                .padding(.leading, 4)
        }
        .frame(height: 22)
    }
}

// MARK: - Timer

struct TimerView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: SessionStore

    var body: some View {
        VStack(spacing: 12) {
            TileGrid(rows: state.timerDigits, editing: state.editing) { state.beginEdit($0) }
            controls
            TodaySummary(total: store.total(for: Date()))
        }
    }

    @ViewBuilder private var controls: some View {
        HStack(spacing: 10) {
            switch state.phase {
            case .idle:
                PillButton(title: "Start", prominent: true) { state.toggle() }
            case .running, .paused:
                PillButton(title: state.phase == .running ? "Pause" : "Resume", prominent: true) { state.toggle() }
                PillButton(title: "Stop") { state.cancel() }
            }
        }
    }
}

struct PillButton: View {
    let title: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(prominent ? .black : .white)
                .padding(.horizontal, prominent ? 22 : 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(prominent ? accent : Color(white: 0.2)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stats (vertical GitHub-style heatmap: rows = weeks, oldest at top)

struct StatsView: View {
    @EnvironmentObject var store: SessionStore

    var body: some View {
        let today = store.total(for: Date())
        VStack(spacing: 18) {
            HStack {
                Stat(value: "\(today.sessions)", label: "Sessions today")
                Stat(value: "\(Int(today.minutes))", label: "Minutes today")
                Stat(value: "\(store.streak)", label: "Day streak")
            }
            Heatmap()
            Legend()
        }
    }
}

private struct Stat: View {
    let value: String, label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 34, weight: .bold).width(.compressed)).foregroundStyle(.white)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(labelGray)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct Heatmap: View {
    @EnvironmentObject var store: SessionStore
    private let cal: Calendar = {
        var c = Calendar.current; c.firstWeekday = 2; return c  // Monday
    }()

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 4
            let headerH: CGFloat = 16
            let cell = min(26, (geo.size.width - gap * 6) / 7)
            let weeks = max(1, min(52, Int((geo.size.height - headerH) / (cell + gap))))
            let today = cal.startOfDay(for: Date())
            let thisMonday = cal.dateInterval(of: .weekOfYear, for: today)!.start

            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    ForEach(["M", "T", "W", "T", "F", "S", "S"].indices, id: \.self) { i in
                        Text(["M", "T", "W", "T", "F", "S", "S"][i])
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(labelGray)
                            .frame(width: cell, height: headerH)
                    }
                }
                ForEach(0..<weeks, id: \.self) { row in
                    let monday = cal.date(byAdding: .day, value: -7 * (weeks - 1 - row), to: thisMonday)!
                    HStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { col in
                            let day = cal.date(byAdding: .day, value: col, to: monday)!
                            DayCell(day: day, total: store.total(for: day), future: day > today,
                                    isToday: day == today, size: cell)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
    }
}

private func heatColor(_ minutes: Double) -> Color {
    switch minutes {
    case ..<1: Color(white: 0.19)
    case ..<25: accent.opacity(0.3)
    case ..<60: accent.opacity(0.55)
    case ..<120: accent.opacity(0.8)
    default: accent
    }
}

private struct DayCell: View {
    let day: Date, total: DayTotal, future: Bool, isToday: Bool, size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
            .fill(future ? Color.clear : heatColor(total.minutes))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .stroke(isToday ? Color.white.opacity(0.7) : .clear, lineWidth: 1)
            )
            .frame(width: size, height: size)
            .help(future ? "" : "\(day.formatted(.dateTime.weekday(.abbreviated).day().month())) — \(Int(total.minutes)) min, \(total.sessions) session\(total.sessions == 1 ? "" : "s")")
    }
}

private struct Legend: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Less").font(.system(size: 10)).foregroundStyle(labelGray)
            ForEach([0.0, 10, 30, 90, 150], id: \.self) { m in
                RoundedRectangle(cornerRadius: 2).fill(heatColor(m)).frame(width: 10, height: 10)
            }
            Text("More").font(.system(size: 10)).foregroundStyle(labelGray)
        }
    }
}

// MARK: - Mode bar

struct ModeBar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 18) {
            ForEach(Mode.allCases, id: \.self) { m in
                Button { state.mode = m } label: {
                    Image(systemName: m.symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(state.mode == m ? accent : labelGray)
                        .frame(width: 30, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }
}
