import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section("Account") {
                HStack {
                    Text(appState.isSignedIn ? "Connected: \(appState.accountEmail)" : "Not signed in")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if appState.isSignedIn {
                        Button("Sign Out") { appState.signOut() }
                    } else {
                        Button("Sign In") { Task { await appState.signIn() } }
                    }
                }
            }

            Section("Import") {
                Toggle("Auto-open spreadsheet in browser", isOn: $settingsStore.autoOpenBrowser)
                TextField("Optional delimiter override (single character)", text: $settingsStore.delimiterOverride)
            }
        }
        .padding(16)
        .frame(width: 520)
    }
}
