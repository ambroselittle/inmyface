import Foundation
import Testing
@testable import InMyFace

@Suite("Meeting")
struct MeetingTests {

    @Test
    func testAlertReflectsConfiguredLeadTimeWithoutJoinState() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let meeting = Meeting.testAlert(now: now, leadTimeSeconds: 120)

        #expect(meeting.title == "Test Alert")
        #expect(meeting.start == now.addingTimeInterval(120))
        #expect(meeting.end == meeting.start.addingTimeInterval(30 * 60))
        #expect(meeting.calendarTitle == "InMyFace")
        #expect(meeting.joinURL == nil)
        #expect(meeting.location == nil)
    }

    @Test
    func testAlertClampsInvalidNegativeLeadTime() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let meeting = Meeting.testAlert(now: now, leadTimeSeconds: -1)

        #expect(meeting.start == now)
    }
}
