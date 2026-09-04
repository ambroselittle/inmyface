import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let calendar = CalendarService()
    private lazy var scheduler = MeetingScheduler(calendar: calendar)
    private let overlay = OverlayController()
    private var menu: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // no Dock icon, menubar only

        menu = MenuBarController(
            scheduler: scheduler,
            calendar: calendar,
            onJoin: { [weak self] meeting in self?.join(meeting) },
            onTestAlert: { [weak self] in self?.showTestAlert() }
        )

        // Overlay ↔ scheduler wiring.
        scheduler.isOverlayVisible = { [weak self] in self?.overlay.isVisible ?? false }
        scheduler.onRefresh = { [weak self] in self?.menu.rebuild() }
        scheduler.onPresent = { [weak self] meetings in self?.showTakeover(for: meetings) }

        Task { @MainActor in
            if calendar.access == .notDetermined {
                _ = await calendar.requestAccess()
            }
            migrateLegacyConfigIfNeeded()
            LoginItem.reconcile(desired: Preferences.launchAtLogin)
            scheduler.start()
            menu.rebuild()
        }
    }

    /// One-time move from the old UserDefaults-keyed settings to the shared
    /// config file, translating machine-local calendar IDs into stable keys so
    /// this Mac keeps its calendar selections and keywords.
    private func migrateLegacyConfigIfNeeded() {
        guard !ConfigStore.exists() else { return }
        let d = UserDefaults.standard
        var cfg = Config()

        if let v = d.object(forKey: "leadTimeSeconds") as? Int { cfg.leadTimeSeconds = v }
        if let v = d.object(forKey: "snoozeMinutes") as? Int { cfg.snoozeMinutes = v }
        if let v = d.object(forKey: "onlyJoinableMeetings") as? Bool { cfg.onlyJoinable = v }
        if let v = d.string(forKey: "menubarStyle") { cfg.menubarStyle = v }
        if let v = d.object(forKey: "soundEnabled") as? Bool { cfg.soundEnabled = v }
        if let v = d.string(forKey: "soundName") { cfg.soundName = v }

        let cals = calendar.allCalendars()
        var idToKey: [String: String] = [:]
        for cal in cals {
            idToKey[cal.calendarIdentifier] = Preferences.calendarKey(source: cal.source?.title, title: cal.title)
        }

        // Old enabled allow-list → new disabled set.
        if let enabledIDs = d.array(forKey: "enabledCalendarIDs") as? [String] {
            let enabled = Set(enabledIDs)
            cfg.disabledCalendars = cals
                .filter { !enabled.contains($0.calendarIdentifier) }
                .compactMap { idToKey[$0.calendarIdentifier] }
                .sorted()
        }

        // Old keywords keyed by calendar ID → keyed by stable key.
        if let legacy = d.dictionary(forKey: "calendarKeywords") as? [String: [String]] {
            var translated: [String: [String]] = [:]
            for (id, words) in legacy {
                if let key = idToKey[id] { translated[key] = words }
            }
            cfg.calendarKeywords = translated
        }

        Preferences.replaceConfig(cfg)
    }

    private func showTakeover(for meetings: [Meeting]) {
        overlay.present(
            meetings: meetings,
            snoozeMinutes: Preferences.snoozeMinutes,
            onJoin: { [weak self] meeting in
                self?.join(meeting)
                meetings.forEach { self?.scheduler.dismiss($0) }
            },
            onSnooze: { [weak self] in
                meetings.forEach { self?.scheduler.snooze($0, minutes: Preferences.snoozeMinutes) }
            },
            onDismiss: { [weak self] in
                meetings.forEach { self?.scheduler.dismiss($0) }
            }
        )
    }

    /// Show one real takeover without involving scheduler state. The synthetic
    /// meeting exists only long enough to render the configured timing, snooze,
    /// visual, and sound behavior; closing it cannot dismiss or snooze a real
    /// calendar occurrence (or persist a fabricated occurrence ID).
    private func showTestAlert() {
        let meeting = Meeting.testAlert(
            leadTimeSeconds: Preferences.leadTimeSeconds
        )
        overlay.present(
            meetings: [meeting],
            snoozeMinutes: Preferences.snoozeMinutes,
            onJoin: { _ in },
            onSnooze: {},
            onDismiss: {}
        )
    }

    private func join(_ meeting: Meeting) {
        guard let url = meeting.joinURL else { return }
        NSWorkspace.shared.open(url)
    }
}
