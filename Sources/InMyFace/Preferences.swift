import Foundation

/// Lightweight UserDefaults-backed settings.
enum Preferences {
    private static let defaults = UserDefaults.standard

    enum Key {
        static let leadTimeSeconds = "leadTimeSeconds"
        static let snoozeMinutes = "snoozeMinutes"
        static let onlyJoinable = "onlyJoinableMeetings"
        static let autoOpenJoin = "autoOpenJoinOnJoinClick"
        static let launchAtLogin = "launchAtLogin"
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
}
