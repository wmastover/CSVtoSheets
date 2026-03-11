import AppKit
import Foundation
import UniformTypeIdentifiers
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var isSignedIn = false
    @Published private(set) var accountEmail = ""
    @Published var importStatus: ImportStatus = .idle
    @Published var lastOpenedFile: URL?
    @Published private(set) var debugEvents: [String] = []

    private var authManager: AuthManager?
    private var importCoordinator: ImportCoordinator?
    private var notificationAuthorizationRequested = false

    func bootstrap(settingsStore: SettingsStore) async {
        await requestNotificationAuthorizationIfNeeded()
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
            postUserNotification(title: "CSV to Sheets startup failed", body: error.localizedDescription)
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
            postUserNotification(title: "Google sign-in failed", body: error.localizedDescription)
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
        appendDebugEvent("Opened CSV: \(url.lastPathComponent)")
        Task {
            await importCSV(url, settings: settings, terminateWhenFinished: true)
        }
    }

    func recordExternalEvent(_ message: String) {
        appendDebugEvent(message)
    }

    func importFromFilePicker(settings: SettingsStore) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            appendDebugEvent("Selected CSV from picker: \(url.lastPathComponent)")
            Task {
                await importCSV(url, settings: settings, terminateWhenFinished: false)
            }
        }
    }

    private func importCSV(_ url: URL, settings: SettingsStore, terminateWhenFinished: Bool) async {
        guard let importCoordinator else { return }
        appendDebugEvent("Starting import")
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
                        self?.appendDebugEvent(message)
                    }
                }
            )
            importStatus = .success(result)
            appendDebugEvent("Import finished: \(result.rowsUploaded) rows")
            appendDebugEvent("Spreadsheet URL: \(result.spreadsheetURL.absoluteString)")
        } catch {
            importStatus = .failure(error.localizedDescription)
            appendDebugEvent("Import failed: \(error.localizedDescription)")
            postUserNotification(title: "CSV import failed", body: error.localizedDescription)
        }
        if terminateWhenFinished {
            terminateAfterImport()
        }
    }

    private func requestNotificationAuthorizationIfNeeded() async {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        guard !notificationAuthorizationRequested else { return }
        notificationAuthorizationRequested = true
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    private func postUserNotification(title: String, body: String) {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func appendDebugEvent(_ message: String) {
        let timestamp = Self.debugTimestampFormatter.string(from: Date())
        let formatted = "\(timestamp)  \(message)"
        if debugEvents.last == formatted { return }
        debugEvents.append(formatted)
        if debugEvents.count > 300 {
            debugEvents.removeFirst(debugEvents.count - 300)
        }
    }

    private func terminateAfterImport() {
        Task { @MainActor in
            // Give browser launch / notification dispatch a brief moment.
            try? await Task.sleep(nanoseconds: 900_000_000)
            NSApp.terminate(nil)
        }
    }

    private static let debugTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
