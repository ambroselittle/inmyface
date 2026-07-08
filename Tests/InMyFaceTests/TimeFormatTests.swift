import XCTest
@testable import InMyFace

final class TimeFormatTests: XCTestCase {

    func testFutureNearIsMinutesSeconds() {
        let s = TimeFormat.countdown(to: Date().addingTimeInterval(100))
        // "01:39" / "01:40" — MM:SS, no negative sign, not the "Started" form.
        XCTAssertNotNil(s.range(of: "^\\d{2}:\\d{2}$", options: .regularExpression))
        XCTAssertFalse(s.contains("-"))
        XCTAssertFalse(s.contains("Started"))
    }

    func testFutureHoursRollsUp() {
        let s = TimeFormat.countdown(to: Date().addingTimeInterval(7_000)) // ~1h56m
        XCTAssertTrue(s.contains("h"))
        XCTAssertFalse(s.contains("Started"))
    }

    func testPastReadsAsElapsed() {
        let s = TimeFormat.countdown(to: Date().addingTimeInterval(-800)) // ~13m20s ago
        XCTAssertTrue(s.hasPrefix("Started"))
        XCTAssertTrue(s.hasSuffix("ago"))
        XCTAssertTrue(s.contains("13m"))
        XCTAssertFalse(s.contains("-"))
        XCTAssertFalse(s.contains(":"))
    }

    func testPastUnderAMinute() {
        let s = TimeFormat.countdown(to: Date().addingTimeInterval(-20))
        XCTAssertTrue(s.hasPrefix("Started"))
        XCTAssertTrue(s.hasSuffix("s ago"))
        XCTAssertFalse(s.contains("m "))
    }
}
