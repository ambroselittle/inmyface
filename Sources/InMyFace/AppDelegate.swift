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
            onPresent: { [weak self] meeting in self?.scheduler.presentNow(meeting) }
        )

        // Overlay ↔ scheduler wiring.
        scheduler.isOverlayVisible = { [weak self] in self?.overlay.isVisible ?? false }
        scheduler.onRefresh = { [weak self] in self?.menu.rebuild() }
        scheduler.onPresent = { [weak self] meeting in self?.showTakeover(for: meeting) }

        Task { @MainActor in
            if calendar.access == .notDetermined {
                _ = await calendar.requestAccess()
            }
            scheduler.start()
            menu.rebuild()
        }
    }

    private func showTakeover(for meeting: Meeting) {
        overlay.present(
            meeting: meeting,
            snoozeMinutes: Preferences.snoozeMinutes,
            onJoin: { [weak self] in
                self?.join(meeting)
                self?.scheduler.dismiss(meeting)
            },
            onSnooze: { [weak self] in
                self?.scheduler.snooze(meeting, minutes: Preferences.snoozeMinutes)
            },
            onDismiss: { [weak self] in
                self?.scheduler.dismiss(meeting)
            }
        )
    }

    private func join(_ meeting: Meeting) {
        guard let url = meeting.joinURL else { return }
        NSWorkspace.shared.open(url)
    }
}
