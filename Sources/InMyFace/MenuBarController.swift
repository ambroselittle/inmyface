import AppKit

/// NSMenuItem that runs a closure when clicked. Saves wiring up target/action
/// selectors for every dynamic item.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: keyEquivalent)
        self.target = self
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func fire() { handler() }
}

/// Owns the status-bar item and (re)builds its menu from scheduler state.
@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let scheduler: MeetingScheduler
    private let calendar: CalendarService
    private let onJoin: (Meeting) -> Void
    private let onPresent: (Meeting) -> Void

    /// Offer these as quick "remind me in N min" choices.
    private let nudgeChoices = [1, 5, 10, 15, 30]

    init(scheduler: MeetingScheduler,
         calendar: CalendarService,
         onJoin: @escaping (Meeting) -> Void,
         onPresent: @escaping (Meeting) -> Void) {
        self.scheduler = scheduler
        self.calendar = calendar
        self.onJoin = onJoin
        self.onPresent = onPresent
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "person.2.wave.2.fill",
                                   accessibilityDescription: "InMyFace")
            button.imagePosition = .imageLeading
        }
        rebuild()
    }

    func rebuild() {
        updateStatusTitle()

        let menu = NSMenu()
        let meetings = Array(scheduler.meetings.prefix(10))

        // Calendar access gate.
        if calendar.access != .granted {
            let warn = NSMenuItem(title: "⚠︎ Calendar access needed", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
            menu.addItem(ClosureMenuItem(title: "Open Privacy Settings…") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            })
            menu.addItem(.separator())
            menu.addItem(ClosureMenuItem(title: "Quit InMyFace", keyEquivalent: "q") {
                NSApp.terminate(nil)
            })
            statusItem.menu = menu
            return
        }

        // Header.
        if let next = meetings.first {
            let header = NSMenuItem(title: nextHeader(next), action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
        } else {
            let none = NSMenuItem(title: "No upcoming meetings", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        }

        // Active custom nudges.
        if !scheduler.customNudges.isEmpty {
            menu.addItem(.separator())
            let label = NSMenuItem(title: "Pending reminders", action: nil, keyEquivalent: "")
            label.isEnabled = false
            menu.addItem(label)
            for nudge in scheduler.customNudges {
                let mins = max(0, Int(nudge.fireDate.timeIntervalSinceNow / 60))
                let item = ClosureMenuItem(title: "  ⏰ \(nudge.meeting.title) — in \(mins) min (cancel)") { [weak self] in
                    self?.scheduler.cancelNudge(nudge.id)
                }
                menu.addItem(item)
            }
        }

        // Upcoming meetings, each with a submenu of actions.
        if !meetings.isEmpty {
            menu.addItem(.separator())
            let label = NSMenuItem(title: "Upcoming", action: nil, keyEquivalent: "")
            label.isEnabled = false
            menu.addItem(label)
            for meeting in meetings {
                menu.addItem(meetingItem(meeting))
            }
        }

        // Settings.
        menu.addItem(.separator())
        menu.addItem(settingsMenuItem())

        // Refresh + Quit.
        menu.addItem(ClosureMenuItem(title: "Refresh now") { [weak self] in
            self?.scheduler.refresh()
        })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "Quit InMyFace", keyEquivalent: "q") {
            NSApp.terminate(nil)
        })

        statusItem.menu = menu
    }

    // MARK: - Building blocks

    private func meetingItem(_ meeting: Meeting) -> NSMenuItem {
        let item = NSMenuItem(title: meetingLabel(meeting), action: nil, keyEquivalent: "")
        if meeting.isJoinable {
            item.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: nil)
        }

        let sub = NSMenu()
        if meeting.isJoinable {
            sub.addItem(ClosureMenuItem(title: "Join now") { [weak self] in
                self?.onJoin(meeting)
            })
        }
        sub.addItem(ClosureMenuItem(title: "Show takeover now") { [weak self] in
            self?.onPresent(meeting)
        })
        sub.addItem(.separator())
        let remindLabel = NSMenuItem(title: "Remind me in…", action: nil, keyEquivalent: "")
        remindLabel.isEnabled = false
        sub.addItem(remindLabel)
        for m in nudgeChoices {
            sub.addItem(ClosureMenuItem(title: "  \(m) min") { [weak self] in
                self?.scheduler.addCustomNudge(for: meeting, minutes: m)
            })
        }
        item.submenu = sub
        return item
    }

    private func settingsMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        let sub = NSMenu()

        // Lead time.
        let leadLabel = NSMenuItem(title: "Show takeover before start", action: nil, keyEquivalent: "")
        leadLabel.isEnabled = false
        sub.addItem(leadLabel)
        for secs in [0, 30, 60, 120, 300] {
            let title = secs == 0 ? "  At start time" : "  \(secs / 60 == 0 ? "\(secs) sec" : "\(secs / 60) min")"
            let choice = ClosureMenuItem(title: title) { [weak self] in
                Preferences.leadTimeSeconds = secs
                self?.rebuild()
            }
            choice.state = (Preferences.leadTimeSeconds == secs) ? .on : .off
            sub.addItem(choice)
        }

        sub.addItem(.separator())

        // Snooze length.
        let snoozeLabel = NSMenuItem(title: "Snooze length", action: nil, keyEquivalent: "")
        snoozeLabel.isEnabled = false
        sub.addItem(snoozeLabel)
        for m in [5, 10, 15] {
            let choice = ClosureMenuItem(title: "  \(m) min") { [weak self] in
                Preferences.snoozeMinutes = m
                self?.rebuild()
            }
            choice.state = (Preferences.snoozeMinutes == m) ? .on : .off
            sub.addItem(choice)
        }

        sub.addItem(.separator())

        // Only joinable toggle.
        let onlyJoinable = ClosureMenuItem(title: "Only meetings with a join link") { [weak self] in
            Preferences.onlyJoinable.toggle()
            self?.rebuild()
        }
        onlyJoinable.state = Preferences.onlyJoinable ? .on : .off
        sub.addItem(onlyJoinable)

        item.submenu = sub
        return item
    }

    // MARK: - Formatting

    private func updateStatusTitle() {
        guard let button = statusItem.button else { return }
        if let next = scheduler.meetings.first {
            let mins = next.minutesUntilStart
            if mins <= 0 {
                button.title = " now"
            } else if mins < 60 {
                button.title = " \(mins)m"
            } else {
                button.title = " \(mins / 60)h\(mins % 60)m"
            }
        } else {
            button.title = ""
        }
    }

    private func timeString(_ date: Date) -> String {
        let df = DateFormatter()
        df.timeStyle = .short
        return df.string(from: date)
    }

    private func meetingLabel(_ meeting: Meeting) -> String {
        "\(timeString(meeting.start))  ·  \(meeting.title)"
    }

    private func nextHeader(_ meeting: Meeting) -> String {
        let mins = meeting.minutesUntilStart
        let rel: String
        if mins <= 0 { rel = "now" }
        else if mins < 60 { rel = "in \(mins) min" }
        else { rel = "in \(mins / 60)h \(mins % 60)m" }
        return "Next: \(meeting.title) — \(rel)"
    }
}
