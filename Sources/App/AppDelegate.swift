import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var appState: AppState? {
        didSet { flushPendingOpenFilesIfReady() }
    }
    weak var settingsStore: SettingsStore? {
        didSet { flushPendingOpenFilesIfReady() }
    }
    private let openHandler = DocumentOpenHandler()
    private var pendingFilenames: [String] = []

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        pendingFilenames.append(contentsOf: filenames)
        flushPendingOpenFilesIfReady()
    }

    private func flushPendingOpenFilesIfReady() {
        guard !pendingFilenames.isEmpty else { return }
        guard let appState, let settingsStore else { return }
        openHandler.handle(paths: pendingFilenames, appState: appState, settingsStore: settingsStore)
        pendingFilenames.removeAll()
    }
}
