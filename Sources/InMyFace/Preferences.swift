import Foundation

/// Settings facade. Shareable settings are backed by a JSON `Config` file in
/// iCloud Drive (see `ConfigStore`); machine-local runtime state stays in
/// UserDefaults.
enum Preferences {
    private static let defaults = UserDefaults.standard

    /// In-memory copy of the shared config, written through on every change.
    private static var config = ConfigStore.load()

    private static func mutate(_ change: (inout Config) -> Void) {
        change(&config)
        ConfigStore.save(config)
    }

    /// Replace the whole config (used by migration) and persist it.
    static func replaceConfig(_ newConfig: Config) {
        config = newConfig
        ConfigStore.save(config)
    }

    static var currentConfig: Config { config }

    // MARK: - Timing / behavior

    static var leadTimeSeconds: Int {
        get { config.leadTimeSeconds }
        set { mutate { $0.leadTimeSeconds = newValue } }
    }

    static var snoozeMinutes: Int {
        get { config.snoozeMinutes }
        set { mutate { $0.snoozeMinutes = newValue } }
    }

    static var onlyJoinable: Bool {
        get { config.onlyJoinable }
        set { mutate { $0.onlyJoinable = newValue } }
    }

    static var launchAtLogin: Bool {
        get { config.launchAtLogin }
        set { mutate { $0.launchAtLogin = newValue } }
    }

    // MARK: - Menu bar appearance

    enum MenubarStyle: String, CaseIterable {
        case iconOnly
        case imminentMinutes
        case dayOfMonth

        var label: String {
            switch self {
            case .iconOnly: return "Icon only"
            case .imminentMinutes: return "Minutes (only when meeting is near)"
            case .dayOfMonth: return "Day of month"
            }
        }
    }

    static var menubarStyle: MenubarStyle {
        get { MenubarStyle(rawValue: config.menubarStyle) ?? .iconOnly }
        set { mutate { $0.menubarStyle = newValue.rawValue } }
    }

    // MARK: - Sound

    static var soundEnabled: Bool {
        get { config.soundEnabled }
        set { mutate { $0.soundEnabled = newValue } }
    }

    static var soundName: String {
        get { config.soundName }
        set { mutate { $0.soundName = newValue } }
    }

    static let availableSounds = [
        "Glass", "Hero", "Ping", "Blow", "Bottle", "Frog",
        "Funk", "Morse", "Pop", "Purr", "Sosumi", "Submarine", "Tink"
    ]

    // MARK: - Calendars (keyed by a stable "account › name" key)

    /// Stable, cross-machine key for a calendar. EventKit's calendarIdentifier
    /// differs per Mac, so we key on the account/source title plus the calendar
    /// title instead.
    static func calendarKey(source: String?, title: String) -> String {
        "\(source ?? "Other")›\(title)"
    }

    /// Enabled unless explicitly disabled. New/other-machine calendars default
    /// on, which is what makes a shared config behave sensibly.
    static func isCalendarEnabled(_ key: String) -> Bool {
        !config.disabledCalendars.contains(key)
    }

    static func setCalendar(_ key: String, enabled: Bool) {
        mutate {
            var disabled = Set($0.disabledCalendars)
            if enabled { disabled.remove(key) } else { disabled.insert(key) }
            $0.disabledCalendars = Array(disabled).sorted()
        }
    }

    static func keywords(for key: String) -> [String] {
        config.calendarKeywords[key] ?? []
    }

    static func setKeywords(_ words: [String], for key: String) {
        mutate {
            if words.isEmpty { $0.calendarKeywords.removeValue(forKey: key) }
            else { $0.calendarKeywords[key] = words }
        }
    }

    /// True if this event title passes its calendar's keyword filter.
    static func titlePassesFilter(_ title: String, calendarKey: String) -> Bool {
        titleMatches(title, keywords: keywords(for: calendarKey))
    }

    /// Case-insensitive substring match; empty keywords always passes.
    static func titleMatches(_ title: String, keywords: [String]) -> Bool {
        guard !keywords.isEmpty else { return true }
        let haystack = title.lowercased()
        return keywords.contains { haystack.contains($0.lowercased()) }
    }

    // MARK: - Local runtime state (not shared)

    enum LocalKey {
        static let dismissedMeetingIDs = "dismissedMeetingIDs"
    }

    static var dismissedMeetingIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: LocalKey.dismissedMeetingIDs) ?? []) }
        set { defaults.set(Array(newValue), forKey: LocalKey.dismissedMeetingIDs) }
    }
}
