import XCTest
@testable import InMyFace

final class ConfigTests: XCTestCase {

    func testRoundTrip() throws {
        var cfg = Config()
        cfg.leadTimeSeconds = 120
        cfg.snoozeMinutes = 10
        cfg.onlyJoinable = true
        cfg.menubarStyle = "dayOfMonth"
        cfg.soundEnabled = false
        cfg.soundName = "Hero"
        cfg.launchAtLogin = true
        cfg.disabledCalendars = ["iCloud›Family", "Google›Holidays"]
        cfg.calendarKeywords = ["iCloud›Family": ["Dad", "Ambrose"]]

        let data = try JSONEncoder().encode(cfg)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(cfg, decoded)
    }

    // Older / partial files must decode, filling every missing field with its
    // default rather than throwing.
    func testPartialDecodeUsesDefaults() throws {
        let json = #"{ "soundName": "Ping", "disabledCalendars": ["iCloud›Fam"] }"#
        let cfg = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
        XCTAssertEqual(cfg.soundName, "Ping")
        XCTAssertEqual(cfg.disabledCalendars, ["iCloud›Fam"])
        // Untouched fields fall back to defaults.
        XCTAssertEqual(cfg.leadTimeSeconds, 60)
        XCTAssertEqual(cfg.snoozeMinutes, 5)
        XCTAssertEqual(cfg.menubarStyle, "iconOnly")
        XCTAssertTrue(cfg.soundEnabled)
        XCTAssertFalse(cfg.launchAtLogin)
    }

    func testEmptyJSONDecodesToDefaults() throws {
        let cfg = try JSONDecoder().decode(Config.self, from: Data("{}".utf8))
        XCTAssertEqual(cfg, Config())
    }

    func testCalendarKeyFormat() {
        XCTAssertEqual(Preferences.calendarKey(source: "iCloud", title: "Family"), "iCloud›Family")
        // Missing source falls back to a stable placeholder.
        XCTAssertEqual(Preferences.calendarKey(source: nil, title: "Work"), "Other›Work")
    }

    func testTitleMatching() {
        // No keywords → everything passes.
        XCTAssertTrue(Preferences.titleMatches("Anything", keywords: []))
        // Case-insensitive substring.
        XCTAssertTrue(Preferences.titleMatches("Lunch with Dad", keywords: ["Dad", "Ambrose"]))
        XCTAssertTrue(Preferences.titleMatches("ambrose piano recital", keywords: ["Dad", "Ambrose"]))
        // No match → filtered out.
        XCTAssertFalse(Preferences.titleMatches("Grocery run", keywords: ["Dad", "Ambrose"]))
    }
}
