import Foundation

@MainActor
struct DocumentOpenHandler {
    func handle(paths: [String], appState: AppState, settingsStore: SettingsStore) {
        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard ["csv", "xlsx"].contains(url.pathExtension.lowercased()) else { continue }
            appState.openFile(url, settings: settingsStore)
        }
    }
}
