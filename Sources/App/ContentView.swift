import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        Group {
            statusItem
            Divider()
            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: [.command])
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }
    }

    @ViewBuilder
    private var statusItem: some View {
        switch appState.importStatus {
        case .idle:
            if appState.isSignedIn {
                Label("Ready — \(appState.accountEmail)", systemImage: "checkmark.circle")
            } else {
                Label("Not signed in", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.secondary)
            }
        case .working(_, let message):
            Label(message, systemImage: "arrow.triangle.2.circlepath")
        case .success(let result):
            Label("\(result.rowsUploaded) rows uploaded", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure(let msg):
            Label(msg, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
