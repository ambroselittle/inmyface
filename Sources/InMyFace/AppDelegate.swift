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
            onJoin: { [weak self] meeting in self?.join(meeting) }
        )

        // Overlay ↔ scheduler wiring.
        scheduler.isOverlayVisible = { [weak self] in self?.overlay.isVisible ?? false }
        scheduler.onRefresh = { [weak self] in self?.menu.rebuild() }
        scheduler.onPresent = { [weak self] meetings in self?.showTakeover(for: meetings) }

        Task { @MainActor in
            if calendar.access == .notDetermined {
                _ = await calendar.requestAccess()
            }
            scheduler.start()
            menu.rebuild()
        }
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

    private func join(_ meeting: Meeting) {
        guard let url = meeting.joinURL else { return }
        NSWorkspace.shared.open(url)
    }
}
