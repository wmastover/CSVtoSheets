import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    let settingsStore = SettingsStore()

    private let openHandler = DocumentOpenHandler()
    private var pendingFilenames: [String] = []
    private var bootstrapped = false
    private var importStatusObserver: AnyCancellable?
    private var debugWindow: NSWindow?
    private var idleShutdownTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        scheduleIdleShutdown()
        Task {
            await appState.bootstrap(settingsStore: settingsStore)
            observeImportStatus()
            bootstrapped = true
            flushPendingOpenFilesIfReady()
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        cancelIdleShutdown()
        appState.recordExternalEvent("Delegate openFiles received: \(filenames.count)")
        pendingFilenames.append(contentsOf: filenames)
        flushPendingOpenFilesIfReady()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        cancelIdleShutdown()
        appState.recordExternalEvent("Delegate open(urls) received: \(urls.count)")
        pendingFilenames.append(contentsOf: urls.map(\.path))
        flushPendingOpenFilesIfReady()
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        cancelIdleShutdown()
        appState.recordExternalEvent("Delegate openFile received")
        pendingFilenames.append(filename)
        flushPendingOpenFilesIfReady()
        return true
    }

    private func flushPendingOpenFilesIfReady() {
        guard !pendingFilenames.isEmpty else { return }
        guard bootstrapped else {
            appState.recordExternalEvent("Queued \(pendingFilenames.count) file(s) until bootstrap completes")
            return
        }
        appState.recordExternalEvent("Processing \(pendingFilenames.count) pending file(s)")
        openHandler.handle(paths: pendingFilenames, appState: appState, settingsStore: settingsStore)
        pendingFilenames.removeAll()
    }

    private func observeImportStatus() {
        importStatusObserver = appState.$importStatus.sink { [weak self] status in
            self?.handleImportStatus(status)
        }
    }

    private func handleImportStatus(_ status: ImportStatus) {
        switch status {
        case .working:
            showDebugWindow()
        case .failure:
            showDebugWindow()
            NSApp.activate(ignoringOtherApps: true)
        case .idle, .success:
            break
        }
    }

    private func showDebugWindow() {
        if debugWindow == nil {
            let rootView = ImportDebugView()
                .environmentObject(appState)
                .environmentObject(settingsStore)
            let hosting = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: hosting)
            window.title = "CSV Import Debug"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 620, height: 440))
            window.setFrameAutosaveName("CSVImportDebugWindow")
            window.isReleasedWhenClosed = false
            debugWindow = window
        }
        debugWindow?.makeKeyAndOrderFront(nil)
    }

    private func scheduleIdleShutdown() {
        idleShutdownTask?.cancel()
        idleShutdownTask = Task { @MainActor in
            // Finder open events usually arrive almost immediately after launch.
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard pendingFilenames.isEmpty else { return }
            guard case .idle = appState.importStatus else { return }
            appState.recordExternalEvent("No file-open event received; terminating idle instance")
            NSApp.terminate(nil)
        }
    }

    private func cancelIdleShutdown() {
        idleShutdownTask?.cancel()
        idleShutdownTask = nil
    }
}
