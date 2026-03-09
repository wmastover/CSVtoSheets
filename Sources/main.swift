import SwiftUI

@main
struct CSVtoSheetsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup("CSV to Sheets") {
            ContentView()
                .environmentObject(appState)
                .environmentObject(settingsStore)
                .task {
                    await appState.bootstrap(settingsStore: settingsStore)
                    appDelegate.appState = appState
                    appDelegate.settingsStore = settingsStore
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(settingsStore)
        }
    }
}
