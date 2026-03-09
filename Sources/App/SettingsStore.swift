import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var autoOpenBrowser: Bool {
        didSet { defaults.set(autoOpenBrowser, forKey: Keys.autoOpenBrowser) }
    }
    @Published var delimiterOverride: String {
        didSet { defaults.set(delimiterOverride, forKey: Keys.delimiterOverride) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let autoOpenBrowser = "settings.autoOpenBrowser"
        static let delimiterOverride = "settings.delimiterOverride"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.autoOpenBrowser = defaults.object(forKey: Keys.autoOpenBrowser) as? Bool ?? true
        self.delimiterOverride = defaults.string(forKey: Keys.delimiterOverride) ?? ""
    }

    var delimiterCharacter: Character? {
        let trimmed = delimiterOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1 else { return nil }
        return trimmed.first
    }
}
