import AppKit
import EventKit

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
    private let icon = NSImage(systemSymbolName: "person.2.wave.2.fill",
                               accessibilityDescription: "InMyFace")

    /// A meeting starting within this window counts as "near" for the
    /// minutes-when-imminent menubar style.
    private let imminentWindow: TimeInterval = 15 * 60

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

        // Calendars + Settings.
        menu.addItem(.separator())
        menu.addItem(calendarsMenuItem())
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

    private func calendarsMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Calendars", action: nil, keyEquivalent: "")
        let sub = NSMenu()

        let cals = calendar.allCalendars()
        let allIDs = cals.map(\.calendarIdentifier)

        if cals.isEmpty {
            let empty = NSMenuItem(title: "No calendars found", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            sub.addItem(empty)
        }

        var lastSource: String?
        for cal in cals {
            let source = cal.source?.title ?? "Other"
            if source != lastSource {
                if lastSource != nil { sub.addItem(.separator()) }
                let hdr = NSMenuItem(title: source, action: nil, keyEquivalent: "")
                hdr.isEnabled = false
                sub.addItem(hdr)
                lastSource = source
            }
            sub.addItem(calendarItem(cal, allIDs: allIDs))
        }

        item.submenu = sub
        return item
    }

    /// One calendar: a submenu with an enable toggle and keyword filter.
    private func calendarItem(_ cal: EKCalendar, allIDs: [String]) -> NSMenuItem {
        let id = cal.calendarIdentifier
        let enabled = Preferences.isCalendarEnabled(id)
        let keywords = Preferences.keywords(for: id)

        var title = cal.title
        if !keywords.isEmpty { title += " — filtered" }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.state = enabled ? .on : .off

        let sub = NSMenu()
        let toggle = ClosureMenuItem(title: enabled ? "Enabled" : "Disabled") { [weak self] in
            Preferences.setCalendar(id, enabled: !enabled, allIDs: allIDs)
            self?.scheduler.refresh()
            self?.rebuild()
        }
        toggle.state = enabled ? .on : .off
        sub.addItem(toggle)

        sub.addItem(.separator())
        let status = NSMenuItem(
            title: keywords.isEmpty ? "Alerts on: all events" : "Alerts on titles with: \(keywords.joined(separator: ", "))",
            action: nil, keyEquivalent: ""
        )
        status.isEnabled = false
        sub.addItem(status)

        sub.addItem(ClosureMenuItem(title: "Set alert keywords…") { [weak self] in
            self?.editKeywords(for: cal)
        })
        if !keywords.isEmpty {
            sub.addItem(ClosureMenuItem(title: "Clear keywords (alert on all)") { [weak self] in
                Preferences.setKeywords([], for: id)
                self?.scheduler.refresh()
                self?.rebuild()
            })
        }

        item.submenu = sub
        return item
    }

    /// Prompt for comma-separated keywords for a calendar.
    private func editKeywords(for cal: EKCalendar) {
        let alert = NSAlert()
        alert.messageText = "Alert keywords for “\(cal.title)”"
        alert.informativeText = "Only events whose title contains one of these words will alert. Separate with commas. Leave blank to alert on all events in this calendar."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = Preferences.keywords(for: cal.calendarIdentifier).joined(separator: ", ")
        field.placeholderString = "e.g. Dad, Ambrose"
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        alert.window.makeFirstResponder(field)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let words = field.stringValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        Preferences.setKeywords(words, for: cal.calendarIdentifier)
        scheduler.refresh()
        rebuild()
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

        sub.addItem(.separator())

        // Menu bar appearance.
        let menubarLabel = NSMenuItem(title: "Menu bar shows", action: nil, keyEquivalent: "")
        menubarLabel.isEnabled = false
        sub.addItem(menubarLabel)
        for style in Preferences.MenubarStyle.allCases {
            let choice = ClosureMenuItem(title: "  \(style.label)") { [weak self] in
                Preferences.menubarStyle = style
                self?.rebuild()
            }
            choice.state = (Preferences.menubarStyle == style) ? .on : .off
            sub.addItem(choice)
        }

        item.submenu = sub
        return item
    }

    // MARK: - Formatting

    private func updateStatusTitle() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageLeading

        switch Preferences.menubarStyle {
        case .iconOnly:
            button.image = icon
            button.title = ""
        case .dayOfMonth:
            // Just the date number, no icon — compact, In-Your-Face style.
            button.image = nil
            button.title = "\(Calendar.current.component(.day, from: Date()))"
        case .imminentMinutes:
            button.image = icon
            if let next = scheduler.meetings.first,
               next.start.timeIntervalSinceNow > 0,
               next.start.timeIntervalSinceNow <= imminentWindow {
                button.title = " " + TimeFormat.menubar(to: next.start)
            } else {
                button.title = ""
            }
        }
    }

    private func meetingLabel(_ meeting: Meeting) -> String {
        "\(TimeFormat.clock(meeting.start))  ·  \(meeting.title)"
    }

    private func nextHeader(_ meeting: Meeting) -> String {
        "Next: \(meeting.title) — \(TimeFormat.relative(to: meeting.start))"
    }
}
