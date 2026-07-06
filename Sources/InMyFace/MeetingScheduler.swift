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

    private(set) var customNudges: [CustomNudge] = []

    /// Called when one or more meetings should be shown full-screen. More than
    /// one means genuinely-distinct meetings start at the same time.
    var onPresent: (([Meeting]) -> Void)?

    /// How close two start times must be to count as "the same slot".
    private let concurrencyTolerance: TimeInterval = 120

    /// Cap on how many meetings we split the takeover across.
    private let maxConcurrent = 3
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
            onPresent?([nudge.meeting])
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
        if let trigger = eligible.min(by: { $0.start < $1.start }) {
            onPresent?(concurrentGroup(around: trigger, in: eligible))
        }
    }

    /// Meetings starting at the same time as `trigger`, deduped and reduced to
    /// the one(s) worth showing. Collapses duplicates that appear on two
    /// calendars, and prefers the copy that actually has a join link.
    private func concurrentGroup(around trigger: Meeting, in eligible: [Meeting]) -> [Meeting] {
        let sameSlot = eligible
            .filter { abs($0.start.timeIntervalSince(trigger.start)) <= concurrencyTolerance }
            .sorted { $0.start < $1.start }

        // Collapse identical join URLs (same meeting invited to two calendars).
        var seenURL = Set<String>()
        var byURL: [Meeting] = []
        for m in sameSlot {
            if let key = m.joinURL?.absoluteString.lowercased() {
                if seenURL.contains(key) { continue }
                seenURL.insert(key)
            }
            byURL.append(m)
        }

        // Collapse identical titles, keeping the joinable copy if there is one
        // (e.g. a work "block" placeholder vs the real invite on another cal).
        var byTitleOrder: [String] = []
        var byTitle: [String: Meeting] = [:]
        for m in byURL {
            let key = m.title.lowercased().trimmingCharacters(in: .whitespaces)
            if let existing = byTitle[key] {
                if !existing.isJoinable && m.isJoinable { byTitle[key] = m }
            } else {
                byTitle[key] = m
                byTitleOrder.append(key)
            }
        }
        var collapsed = byTitleOrder.compactMap { byTitle[$0] }

        // If any survivor is joinable, drop the link-less ones — they're almost
        // always the placeholder for the same slot.
        if collapsed.contains(where: { $0.isJoinable }) {
            collapsed = collapsed.filter { $0.isJoinable }
        }

        return Array(collapsed.prefix(maxConcurrent))
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

    /// Force-show one or more meetings immediately (developer previews).
    func presentNow(_ meetings: [Meeting]) {
        guard !meetings.isEmpty else { return }
        onPresent?(meetings)
    }
}
