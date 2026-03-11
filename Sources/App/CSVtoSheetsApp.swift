import SwiftUI

@main
struct CSVtoSheetsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("CSV to Sheets", systemImage: "tablecells") {
            ContentView()
                .environmentObject(appDelegate.appState)
                .environmentObject(appDelegate.settingsStore)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState)
                .environmentObject(appDelegate.settingsStore)
        }
    }
}
