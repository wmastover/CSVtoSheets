import SwiftUI

struct ImportDebugView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CSV Import Debug")
                .font(.title3)
                .bold()

            statusSection

            Toggle("Auto-open spreadsheet in browser", isOn: $settingsStore.autoOpenBrowser)

            GroupBox("Event Log") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(appState.debugEvents, id: \.self) { event in
                            Text(event)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 620, minHeight: 440)
    }

    @ViewBuilder
    private var statusSection: some View {
        GroupBox("Status") {
            switch appState.importStatus {
            case .idle:
                Text("Idle")
                    .foregroundStyle(.secondary)
            case .working(let progress, let message):
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: progress)
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            case .success(let result):
                VStack(alignment: .leading, spacing: 6) {
                    Text("Success: \(result.rowsUploaded) rows uploaded")
                        .foregroundStyle(.green)
                    Text(result.spreadsheetURL.absoluteString)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            case .failure(let message):
                Text(message)
                    .foregroundStyle(.red)
            }
        }
    }
}
