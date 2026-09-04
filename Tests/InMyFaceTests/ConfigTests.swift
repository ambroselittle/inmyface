import Foundation
import Testing
@testable import InMyFace

@Suite("Config")
struct ConfigTests {

    @Test
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
        #expect(cfg == decoded)
    }

    // Older / partial files must decode, filling every missing field with its
    // default rather than throwing.
    @Test
    func testPartialDecodeUsesDefaults() throws {
        let json = #"{ "soundName": "Ping", "disabledCalendars": ["iCloud›Fam"] }"#
        let cfg = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
        #expect(cfg.soundName == "Ping")
        #expect(cfg.disabledCalendars == ["iCloud›Fam"])
        // Untouched fields fall back to defaults.
        #expect(cfg.leadTimeSeconds == 60)
        #expect(cfg.snoozeMinutes == 5)
        #expect(cfg.menubarStyle == "iconOnly")
        #expect(cfg.soundEnabled)
        #expect(!cfg.launchAtLogin)
    }

    @Test
    func testEmptyJSONDecodesToDefaults() throws {
        let cfg = try JSONDecoder().decode(Config.self, from: Data("{}".utf8))
        #expect(cfg == Config())
    }

    @Test
    func testCalendarKeyFormat() {
        #expect(Preferences.calendarKey(source: "iCloud", title: "Family") == "iCloud›Family")
        // Missing source falls back to a stable placeholder.
        #expect(Preferences.calendarKey(source: nil, title: "Work") == "Other›Work")
    }

    @Test
    func testTitleMatching() {
        // No keywords → everything passes.
        #expect(Preferences.titleMatches("Anything", keywords: []))
        // Case-insensitive substring.
        #expect(Preferences.titleMatches("Lunch with Dad", keywords: ["Dad", "Ambrose"]))
        #expect(Preferences.titleMatches("ambrose piano recital", keywords: ["Dad", "Ambrose"]))
        // No match → filtered out.
        #expect(!Preferences.titleMatches("Grocery run", keywords: ["Dad", "Ambrose"]))
    }
}
