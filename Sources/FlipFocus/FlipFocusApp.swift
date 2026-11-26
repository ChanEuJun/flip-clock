import SwiftUI

@main
struct FlipFocusApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        Window("FlipFocus", id: "main") {
            ContentView()
                .environmentObject(state)
                .environmentObject(state.store)
                .frame(minWidth: 200, minHeight: 220)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 430, height: 940)
        .commands {
            CommandMenu("Focus") {
                Button("Clock") { state.mode = .clock }.keyboardShortcut("1")
                Button("Timer") { state.mode = .timer }.keyboardShortcut("2")
                Button("Stats") { state.mode = .stats }.keyboardShortcut("3")
                Divider()
                Button(state.phase == .running ? "Pause Timer" : "Start Timer") { state.toggle() }
                    .keyboardShortcut(.return)
                Button("Stop Timer") { state.cancel() }
                    .keyboardShortcut(".")
                    .disabled(state.phase == .idle)
                Divider()
                Toggle("Keep on Top", isOn: $state.keepOnTop).keyboardShortcut("t", modifiers: [.command, .shift])
                Button("Fit Width to Clock") { state.fitWidth() }
                    .keyboardShortcut("0")
                Button("Snap to Right Edge") { state.snap(right: true) }
                    .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                Button("Snap to Left Edge") { state.snap(right: false) }
                    .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            }
        }
    }
}
