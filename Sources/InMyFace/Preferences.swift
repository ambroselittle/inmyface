import Foundation

/// Lightweight UserDefaults-backed settings.
enum Preferences {
    private static let defaults = UserDefaults.standard

    enum Key {
        static let leadTimeSeconds = "leadTimeSeconds"
        static let snoozeMinutes = "snoozeMinutes"
        static let onlyJoinable = "onlyJoinableMeetings"
        static let enabledCalendarIDs = "enabledCalendarIDs"
        static let calendarKeywords = "calendarKeywords"
        static let menubarStyle = "menubarStyle"
    }

    /// What the status-bar item shows. Kept minimal — most users already have
    /// the clock/date in the menu bar, so the default is just an icon.
    enum MenubarStyle: String, CaseIterable {
        case iconOnly          // just the icon, no text
        case imminentMinutes   // icon; adds minutes only when a meeting is close
        case dayOfMonth        // today's date number, In-Your-Face style

        var label: String {
            switch self {
            case .iconOnly: return "Icon only"
            case .imminentMinutes: return "Minutes (only when meeting is near)"
            case .dayOfMonth: return "Day of month"
            }
        }
    }

    static var menubarStyle: MenubarStyle {
        get { MenubarStyle(rawValue: defaults.string(forKey: Key.menubarStyle) ?? "") ?? .iconOnly }
        set { defaults.set(newValue.rawValue, forKey: Key.menubarStyle) }
    }

    /// How many seconds before start the takeover appears. Default 60s.
    static var leadTimeSeconds: Int {
        get { defaults.object(forKey: Key.leadTimeSeconds) as? Int ?? 60 }
        set { defaults.set(newValue, forKey: Key.leadTimeSeconds) }
    }

    /// Default snooze length in minutes. Default 5.
    static var snoozeMinutes: Int {
        get { defaults.object(forKey: Key.snoozeMinutes) as? Int ?? 5 }
        set { defaults.set(newValue, forKey: Key.snoozeMinutes) }
    }

    /// If true, only meetings that have a join link trigger the takeover.
    static var onlyJoinable: Bool {
        get { defaults.object(forKey: Key.onlyJoinable) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.onlyJoinable) }
    }

    /// Calendar identifiers the user has explicitly enabled. `nil` means the
    /// user hasn't chosen yet — treat every calendar as enabled until they do.
    static var enabledCalendarIDs: Set<String>? {
        get {
            guard let arr = defaults.array(forKey: Key.enabledCalendarIDs) as? [String] else { return nil }
            return Set(arr)
        }
        set {
            if let set = newValue {
                defaults.set(Array(set), forKey: Key.enabledCalendarIDs)
            } else {
                defaults.removeObject(forKey: Key.enabledCalendarIDs)
            }
        }
    }

    /// Whether a given calendar should be included. Unset preference = all on.
    static func isCalendarEnabled(_ id: String) -> Bool {
        guard let enabled = enabledCalendarIDs else { return true }
        return enabled.contains(id)
    }

    /// Turn one calendar on/off. Seeds the set from `allIDs` the first time so
    /// toggling one calendar off doesn't silently disable every other.
    static func setCalendar(_ id: String, enabled: Bool, allIDs: [String]) {
        var set = enabledCalendarIDs ?? Set(allIDs)
        if enabled { set.insert(id) } else { set.remove(id) }
        enabledCalendarIDs = set
    }

    // MARK: - Per-calendar keyword filters

    private static var keywordMap: [String: [String]] {
        get { defaults.dictionary(forKey: Key.calendarKeywords) as? [String: [String]] ?? [:] }
        set { defaults.set(newValue, forKey: Key.calendarKeywords) }
    }

    /// Keywords for a calendar. Empty means "alert on every event".
    static func keywords(for id: String) -> [String] {
        keywordMap[id] ?? []
    }

    static func setKeywords(_ words: [String], for id: String) {
        var map = keywordMap
        if words.isEmpty { map.removeValue(forKey: id) } else { map[id] = words }
        keywordMap = map
    }

    /// True if this event title passes its calendar's keyword filter.
    /// Matching is case-insensitive substring; no keywords = always passes.
    static func titlePassesFilter(_ title: String, calendarID: String) -> Bool {
        let words = keywords(for: calendarID)
        guard !words.isEmpty else { return true }
        let haystack = title.lowercased()
        return words.contains { haystack.contains($0.lowercased()) }
    }
}
