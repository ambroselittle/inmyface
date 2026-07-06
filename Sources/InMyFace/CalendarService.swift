import Foundation
import EventKit

/// Wraps EventKit: authorization + fetching upcoming meetings from all
/// calendars the user has added to macOS Calendar.app (including Google).
@MainActor
final class CalendarService {
    private let store = EKEventStore()

    enum Access {
        case granted
        case denied
        case notDetermined
    }

    var access: Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .authorized: return .granted   // legacy value on older systems
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    /// Requests full calendar access (macOS 14+ API).
    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            NSLog("InMyFace: calendar access request failed: \(error)")
            return false
        }
    }

    /// Upcoming meetings within the given window (default: next 24h),
    /// sorted by start time, all-day events excluded.
    func upcomingMeetings(within hours: Double = 24) -> [Meeting] {
        guard access == .granted else { return [] }
        let now = Date()
        let end = now.addingTimeInterval(hours * 3600)
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-300),
                                                 end: end,
                                                 calendars: nil)
        let events = store.events(matching: predicate)
        return events
            .filter { !$0.isAllDay }
            .filter { ($0.endDate ?? .distantPast) > now }   // hasn't fully ended
            .map(Meeting.init(event:))
            .sorted { $0.start < $1.start }
    }
}
