import Foundation

/// The shareable settings, serialized to a JSON file in a well-known iCloud
/// Drive location so the same config follows you across Macs. Only settings
/// that make sense to share live here; machine-local runtime state (like
/// which meetings you've already dismissed) stays in UserDefaults.
struct Config: Codable, Equatable {
    var leadTimeSeconds = 60
    var snoozeMinutes = 5
    var onlyJoinable = false
    var menubarStyle = "iconOnly"
    var soundEnabled = true
    var soundName = "Glass"
    var launchAtLogin = false

    /// Calendars the user turned OFF, keyed by stable "account › name" keys.
    /// A disabled *set* (not an enabled one) is what makes sharing work: a
    /// calendar that only exists on the other Mac isn't listed here, so it
    /// stays enabled by default there.
    var disabledCalendars: [String] = []

    /// Per-calendar alert keywords, keyed by the same stable calendar key.
    var calendarKeywords: [String: [String]] = [:]

    // Tolerate partial / older files: every field falls back to its default.
    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func v<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? nil ?? fallback
        }
        leadTimeSeconds = v(.leadTimeSeconds, 60)
        snoozeMinutes = v(.snoozeMinutes, 5)
        onlyJoinable = v(.onlyJoinable, false)
        menubarStyle = v(.menubarStyle, "iconOnly")
        soundEnabled = v(.soundEnabled, true)
        soundName = v(.soundName, "Glass")
        launchAtLogin = v(.launchAtLogin, false)
        disabledCalendars = v(.disabledCalendars, [])
        calendarKeywords = v(.calendarKeywords, [:])
    }
}

/// Loads and saves `Config` as JSON. Prefers iCloud Drive → `settings/`.
enum ConfigStore {
    /// Where the config file lives. iCloud Drive if available, else local
    /// Application Support.
    static func fileURL() -> URL {
        let fm = FileManager.default
        let cloudDocs = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)

        let dir: URL
        if fm.fileExists(atPath: cloudDocs.path) {
            dir = cloudDocs.appendingPathComponent("settings", isDirectory: true)
        } else {
            dir = fm.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/InMyFace", isDirectory: true)
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("inmyface.json")
    }

    static func load() -> Config {
        guard let data = try? Data(contentsOf: fileURL()),
              let config = try? JSONDecoder().decode(Config.self, from: data)
        else { return Config() }
        return config
    }

    static func save(_ config: Config) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: fileURL(), options: .atomic)
    }

    /// Whether a config file already exists (used to decide on migration).
    static func exists() -> Bool {
        FileManager.default.fileExists(atPath: fileURL().path)
    }
}
