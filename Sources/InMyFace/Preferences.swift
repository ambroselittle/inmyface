import Foundation

/// Lightweight UserDefaults-backed settings.
enum Preferences {
    private static let defaults = UserDefaults.standard

    enum Key {
        static let leadTimeSeconds = "leadTimeSeconds"
        static let snoozeMinutes = "snoozeMinutes"
        static let onlyJoinable = "onlyJoinableMeetings"
        static let enabledCalendarIDs = "enabledCalendarIDs"
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
}
