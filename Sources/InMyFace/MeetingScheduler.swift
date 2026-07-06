import Foundation

/// One-off "remind me in N minutes" nudge the user created for a meeting.
struct CustomNudge: Identifiable {
    let id = UUID()
    let meeting: Meeting   // snapshot, so it survives even if the event refreshes
    let fireDate: Date
}

/// Owns the meeting list and all trigger state, and decides *when* to throw
/// the takeover in your face. UI-agnostic: it calls `onPresent` with the
/// meeting to show. AppDelegate wires that to the overlay.
@MainActor
final class MeetingScheduler {
    private let calendar: CalendarService
    private var timer: Timer?

    private(set) var meetings: [Meeting] = []

    // Trigger bookkeeping, keyed by Meeting.id (per-occurrence).
    private var dismissedIDs: Set<String> = []
    private var snoozedUntil: [String: Date] = [:]
    private var lastPresentedID: String?

    private(set) var customNudges: [CustomNudge] = []

    /// Called when a meeting should be shown full-screen.
    var onPresent: ((Meeting) -> Void)?
    /// Called after the meeting list refreshes, so the menu can redraw.
    var onRefresh: (() -> Void)?
    /// Whether a takeover is currently on screen (set by AppDelegate).
    var isOverlayVisible: () -> Bool = { false }

    /// How far past start we still consider a meeting worth surfacing.
    private let graceWindow: TimeInterval = 5 * 60

    init(calendar: CalendarService) {
        self.calendar = calendar
    }

    func start() {
        refresh()
        // Tick often enough to feel prompt, cheap enough to ignore.
        let t = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func refresh() {
        meetings = calendar.upcomingMeetings(within: 24)
        // Drop stale bookkeeping for meetings no longer in the window.
        let live = Set(meetings.map(\.id))
        dismissedIDs.formIntersection(live)
        snoozedUntil = snoozedUntil.filter { live.contains($0.key) }
        customNudges.removeAll { $0.fireDate < Date().addingTimeInterval(-graceWindow) }
        onRefresh?()
    }

    private func tick() {
        refresh()
        guard !isOverlayVisible() else { return }

        let now = Date()

        // 1. Custom "remind me in N" nudges take priority.
        if let idx = customNudges.firstIndex(where: { $0.fireDate <= now }) {
            let nudge = customNudges.remove(at: idx)
            lastPresentedID = nudge.meeting.id
            onPresent?(nudge.meeting)
            onRefresh?()
            return
        }

        // 2. Imminent meetings.
        let lead = TimeInterval(Preferences.leadTimeSeconds)
        let eligible = meetings.filter { m in
            guard now >= m.start.addingTimeInterval(-lead) else { return false }
            guard now <= m.start.addingTimeInterval(graceWindow) else { return false }
            guard !dismissedIDs.contains(m.id) else { return false }
            if let until = snoozedUntil[m.id], now < until { return false }
            if Preferences.onlyJoinable && !m.isJoinable { return false }
            return true
        }
        if let next = eligible.min(by: { $0.start < $1.start }) {
            lastPresentedID = next.id
            onPresent?(next)
        }
    }

    // MARK: - User actions from the overlay

    func dismiss(_ meeting: Meeting) {
        dismissedIDs.insert(meeting.id)
    }

    func snooze(_ meeting: Meeting, minutes: Int) {
        snoozedUntil[meeting.id] = Date().addingTimeInterval(TimeInterval(minutes * 60))
    }

    // MARK: - Custom nudges (the "remind me in N min" feature)

    func addCustomNudge(for meeting: Meeting, minutes: Int) {
        let fire = Date().addingTimeInterval(TimeInterval(minutes * 60))
        customNudges.append(CustomNudge(meeting: meeting, fireDate: fire))
        customNudges.sort { $0.fireDate < $1.fireDate }
        onRefresh?()
    }

    func cancelNudge(_ id: UUID) {
        customNudges.removeAll { $0.id == id }
        onRefresh?()
    }

    /// Force-show a meeting immediately (menu "Show now" / testing).
    func presentNow(_ meeting: Meeting) {
        onPresent?(meeting)
    }
}
