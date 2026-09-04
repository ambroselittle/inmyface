import Foundation
import Testing
@testable import InMyFace

@Suite("Time formatting")
struct TimeFormatTests {

    @Test
    func testFutureNearIsMinutesSeconds() {
        let s = TimeFormat.countdown(to: Date().addingTimeInterval(100))
        // "01:39" / "01:40" — MM:SS, no negative sign, not the "Started" form.
        #expect(s.range(of: "^\\d{2}:\\d{2}$", options: .regularExpression) != nil)
        #expect(!s.contains("-"))
        #expect(!s.contains("Started"))
    }

    @Test
    func testFutureHoursRollsUp() {
        let s = TimeFormat.countdown(to: Date().addingTimeInterval(7_000)) // ~1h56m
        #expect(s.contains("h"))
        #expect(!s.contains("Started"))
    }

    @Test
    func testPastReadsAsElapsed() {
        let s = TimeFormat.countdown(to: Date().addingTimeInterval(-800)) // ~13m20s ago
        #expect(s.hasPrefix("Started"))
        #expect(s.hasSuffix("ago"))
        #expect(s.contains("13m"))
        #expect(!s.contains("-"))
        #expect(!s.contains(":"))
    }

    @Test
    func testPastUnderAMinute() {
        let s = TimeFormat.countdown(to: Date().addingTimeInterval(-20))
        #expect(s.hasPrefix("Started"))
        #expect(s.hasSuffix("s ago"))
        #expect(!s.contains("m "))
    }
}
