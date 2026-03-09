import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var isSignedIn = false
    @Published private(set) var accountEmail = ""
    @Published var importStatus: ImportStatus = .idle
    @Published var lastOpenedFile: URL?

    private var authManager: AuthManager?
    private var importCoordinator: ImportCoordinator?

    func bootstrap(settingsStore: SettingsStore) async {
        do {
            let config = try AuthManager.loadConfig()
            let manager = AuthManager(config: config)
            self.authManager = manager
            self.importCoordinator = ImportCoordinator(authManager: manager)

            if let token = try await manager.restoreToken() {
                isSignedIn = true
                accountEmail = await manager.fetchAccountEmail(accessToken: token.accessToken) ?? "Connected"
            }
        } catch {
            importStatus = .failure("Startup error: \(error.localizedDescription)")
        }
    }

    func signIn() async {
        guard let authManager else { return }
        do {
            let token = try await authManager.signIn()
            isSignedIn = true
            accountEmail = await authManager.fetchAccountEmail(accessToken: token.accessToken) ?? "Connected"
        } catch {
            importStatus = .failure(error.localizedDescription)
        }
    }

    func signOut() {
        guard let authManager else { return }
        do {
            try authManager.signOut()
            isSignedIn = false
            accountEmail = ""
        } catch {
            importStatus = .failure(error.localizedDescription)
        }
    }

    func openCSVFile(_ url: URL, settings: SettingsStore) {
        lastOpenedFile = url
        Task {
            await importCSV(url, settings: settings)
        }
    }

    func importFromFilePicker(settings: SettingsStore) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            openCSVFile(url, settings: settings)
        }
    }

    private func importCSV(_ url: URL, settings: SettingsStore) async {
        guard let importCoordinator else { return }
        do {
            let request = ImportRequest(
                sourceURL: url,
                delimiterOverride: settings.delimiterCharacter,
                customTitle: nil
            )
            importStatus = .working(progress: 0, message: "Starting import")
            let result = try await importCoordinator.runImport(
                request: request,
                autoOpenBrowser: settings.autoOpenBrowser,
                progress: { [weak self] value, message in
                    await MainActor.run {
                        self?.importStatus = .working(progress: value, message: message)
                    }
                }
            )
            importStatus = .success(result)
        } catch {
            importStatus = .failure(error.localizedDescription)
        }
    }
}
