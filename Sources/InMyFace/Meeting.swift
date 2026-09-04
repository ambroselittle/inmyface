import Foundation
import EventKit

/// A single occurrence of a calendar event that InMyFace can nudge you about.
struct Meeting: Identifiable, Equatable {
    let id: String            // stable per occurrence: eventIdentifier + start time
    let title: String
    let start: Date
    let end: Date
    let calendarKey: String   // stable "account › name" key for settings
    let calendarTitle: String
    let calendarColor: String // hex, best effort
    let joinURL: URL?
    let location: String?

    var isJoinable: Bool { joinURL != nil }

    static func == (lhs: Meeting, rhs: Meeting) -> Bool { lhs.id == rhs.id }
}

extension Meeting {
    init(event: EKEvent) {
        let start = event.startDate ?? Date()
        self.id = "\(event.eventIdentifier ?? UUID().uuidString)@\(Int(start.timeIntervalSince1970))"
        self.title = (event.title?.isEmpty == false ? event.title! : "(No title)")
        self.start = start
        self.end = event.endDate ?? start.addingTimeInterval(1800)
        let calTitle = event.calendar?.title ?? "Calendar"
        self.calendarKey = Preferences.calendarKey(source: event.calendar?.source?.title, title: calTitle)
        self.calendarTitle = calTitle
        self.calendarColor = event.calendar?.color?.hexString ?? "#4C8BF5"
        self.location = event.location?.isEmpty == false ? event.location : nil
        self.joinURL = MeetingLink.find(in: event)
    }

    /// An ephemeral meeting used by Settings → Test Alert. Its start time is
    /// offset by the configured lead time so the takeover previews the same
    /// countdown a real alert would show, but it is never sent to the scheduler.
    static func testAlert(now: Date = Date(), leadTimeSeconds: Int) -> Meeting {
        let start = now.addingTimeInterval(TimeInterval(max(0, leadTimeSeconds)))
        return Meeting(
            id: "test-alert-\(UUID().uuidString)",
            title: "Test Alert",
            start: start,
            end: start.addingTimeInterval(30 * 60),
            calendarKey: "inmyface›test-alert",
            calendarTitle: "InMyFace",
            calendarColor: "#4C8BF5",
            joinURL: nil,
            location: nil
        )
    }
}

#if DEVELOPER
extension Meeting {
    /// Fabricated meeting for overlay previews in debug builds.
    static func sample(title: String = "Sample Meeting",
                       offset: TimeInterval = 45,
                       joinable: Bool = true,
                       color: String = "#4C8BF5") -> Meeting {
        let start = Date().addingTimeInterval(offset)
        return Meeting(
            id: "sample-\(title)-\(Int(offset))",
            title: title,
            start: start,
            end: start.addingTimeInterval(1800),
            calendarKey: "sample›\(title)",
            calendarTitle: "Work",
            calendarColor: color,
            joinURL: joinable ? URL(string: "https://meet.google.com/sample-abc-def") : nil,
            location: nil
        )
    }
}
#endif
