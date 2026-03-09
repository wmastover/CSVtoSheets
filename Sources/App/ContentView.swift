import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CSV to Sheets for macOS")
                .font(.title2)
                .bold()

            accountSection
            importSection
            statusSection
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 360)
    }

    @ViewBuilder
    private var accountSection: some View {
        GroupBox("Google Account") {
            HStack {
                Text(appState.isSignedIn ? "Connected: \(appState.accountEmail)" : "Not signed in")
                    .foregroundStyle(.secondary)
                Spacer()
                if appState.isSignedIn {
                    Button("Sign Out") {
                        appState.signOut()
                    }
                } else {
                    Button("Sign In") {
                        Task { await appState.signIn() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var importSection: some View {
        GroupBox("Import") {
            HStack {
                Button("Open CSV and Import") {
                    appState.importFromFilePicker(settings: settingsStore)
                }
                .keyboardShortcut("o", modifiers: [.command])

                Spacer()
                if let file = appState.lastOpenedFile {
                    Text(file.lastPathComponent)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        GroupBox("Status") {
            switch appState.importStatus {
            case .idle:
                Text("Ready.")
                    .foregroundStyle(.secondary)
            case .working(let progress, let message):
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: progress)
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            case .success(let result):
                VStack(alignment: .leading, spacing: 8) {
                    Text("Import complete (\(result.rowsUploaded) rows).")
                        .foregroundColor(.green)
                    Text(result.spreadsheetURL.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            case .failure(let errorMessage):
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
    }
}
