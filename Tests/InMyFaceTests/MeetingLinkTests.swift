import XCTest
@testable import InMyFace

final class MeetingLinkTests: XCTestCase {

    // The core regression: a non-conferencing link (Facebook event page) must
    // never be treated as a join target.
    func testFacebookLinkIsNotConferencing() {
        let url = URL(string: "https://www.facebook.com/events/1234567890")!
        XCTAssertNil(MeetingLink.conferencingURL(from: url))
        XCTAssertFalse(MeetingLink.isConferencing(url))
    }

    func testZoomAndMeetAreConferencing() {
        XCTAssertNotNil(MeetingLink.conferencingURL(from: URL(string: "https://us02web.zoom.us/j/98765432100")!))
        XCTAssertNotNil(MeetingLink.conferencingURL(from: URL(string: "https://meet.google.com/abc-defg-hij")!))
        XCTAssertNotNil(MeetingLink.conferencingURL(from: URL(string: "https://acme.webex.com/meet/room")!))
    }

    // Notes containing both a Facebook link and a Zoom link: pick the Zoom one,
    // even though Facebook appears first.
    func testPicksConferencingLinkAmongOthers() {
        let notes = """
        Reminder: RSVP on https://www.facebook.com/events/42 first.
        Then join the call here: https://us02web.zoom.us/j/11122233344?pwd=abc
        Agenda doc: https://docs.google.com/document/d/xyz
        """
        let found = MeetingLink.firstConferencingURL(in: notes)
        XCTAssertEqual(found?.host, "us02web.zoom.us")
    }

    func testNoConferencingLinkReturnsNil() {
        let notes = "See https://www.facebook.com/events/42 and https://maps.apple.com/?q=office"
        XCTAssertNil(MeetingLink.firstConferencingURL(in: notes))
    }

    // Outlook SafeLinks wraps the real URL in a ?url= param — unwrap it.
    func testUnwrapsOutlookSafeLink() {
        let inner = "https%3A%2F%2Fus02web.zoom.us%2Fj%2F55566677788"
        let wrapped = URL(string: "https://nam12.safelinks.protection.outlook.com/?url=\(inner)&data=x")!
        let resolved = MeetingLink.conferencingURL(from: wrapped)
        XCTAssertEqual(resolved?.host, "us02web.zoom.us")
    }

    // A custom-domain link under a "Video Call" label (e.g. the St. Isaac the
    // Syrian meeting's philokalia.link) is not a known conferencing host, but
    // the label makes it a valid join target.
    func testLabeledCustomDomainVideoCall() {
        let notes = "----( Video Call )----\nhttps://philokalia.link/climacus\n---===---"
        XCTAssertNil(MeetingLink.firstConferencingURL(in: notes)) // unknown host, not tier 1
        XCTAssertEqual(MeetingLink.labeledURL(in: notes)?.absoluteString, "https://philokalia.link/climacus")
    }

    func testLabeledInlineCue() {
        let notes = "Join the meeting: https://rooms.example.org/abc123"
        XCTAssertEqual(MeetingLink.labeledURL(in: notes)?.absoluteString, "https://rooms.example.org/abc123")
    }

    // A bare event/RSVP link with no video-call cue must NOT be grabbed.
    func testLabeledIgnoresUncuedLinks() {
        XCTAssertNil(MeetingLink.labeledURL(in: "RSVP here: https://www.facebook.com/events/42"))
        XCTAssertNil(MeetingLink.labeledURL(in: "Join us for drinks! https://www.facebook.com/events/42"))
    }

    func testProviderNames() {
        XCTAssertEqual(MeetingLink.providerName(for: URL(string: "https://us02web.zoom.us/j/1")!), "Zoom")
        XCTAssertEqual(MeetingLink.providerName(for: URL(string: "https://meet.google.com/x")!), "Google Meet")
        XCTAssertEqual(MeetingLink.providerName(for: URL(string: "https://acme.webex.com/m")!), "Webex")
    }
}
