import Foundation

@MainActor
struct DocumentOpenHandler {
    func handle(paths: [String], appState: AppState, settingsStore: SettingsStore) {
        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard url.pathExtension.lowercased() == "csv" else { continue }
            appState.openCSVFile(url, settings: settingsStore)
        }
    }
}
