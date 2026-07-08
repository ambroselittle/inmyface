import Foundation
import EventKit
import AppKit

/// Extracts a *video-conferencing* join URL from a calendar event. Only known
/// conferencing hosts are ever returned — a generic link on the event (a
/// Facebook event page, a doc, a maps link) must never be offered as "Join".
enum MeetingLink {
    /// Known conferencing host suffixes. Subdomains match automatically, so
    /// "zoom.us" also covers "acme.zoom.us".
    private static let conferencingHosts: [String] = [
        "zoom.us",
        "zoomgov.com",
        "meet.google.com",
        "teams.microsoft.com",
        "teams.live.com",
        "webex.com",
        "whereby.com",
        "gotomeeting.com",
        "gotomeet.me",
        "bluejeans.com",
        "chime.aws",
        "jit.si",
        "gather.town",
        "around.co",
        "8x8.vc",
        "vowel.com",
        "riverside.fm",
        "meet.zoho.com",
        "livestorm.co",
        "demio.com",
        "skype.com",
    ]

    /// Hosts that wrap the real link in a query param (link protection /
    /// tracking redirects). We unwrap these to reach the actual meeting URL.
    private static let redirectHosts: [String] = [
        "safelinks.protection.outlook.com",
        "google.com",
        "urldefense.com",
        "urldefense.proofpoint.com",
    ]

    /// Phrases that, sitting next to a URL in the notes, mark it as a join link
    /// even when the host isn't a recognized conferencing domain (custom
    /// domains, self-hosted rooms, call link-shorteners). Deliberately specific
    /// — bare "join" is excluded so an RSVP/event link isn't misread.
    private static let videoCallCues: [String] = [
        "video call", "video conference", "videocall",
        "join the meeting", "join meeting", "join the call", "join call",
        "meeting link", "meeting url", "conference link", "call link",
        "join zoom", "join microsoft teams", "join google meet",
        "dial-in", "dial in", "webinar",
    ]

    static func find(in event: EKEvent) -> URL? {
        // 1. The structured url field, if it's a known conferencing link.
        if let url = event.url, let c = conferencingURL(from: url) { return c }
        // 2. First known conferencing link in the notes/body.
        if let notes = event.notes, let url = firstConferencingURL(in: notes) { return url }
        // 3. The location field (Zoom links often live here).
        if let loc = event.location, let url = firstConferencingURL(in: loc) { return url }
        // 4. A URL explicitly labeled as a video call, even on an unknown host.
        if let notes = event.notes, let url = labeledURL(in: notes) { return url }
        if let loc = event.location, let url = labeledURL(in: loc) { return url }
        // No blind fallback — better no Join button than a wrong one.
        return nil
    }

    /// A URL in the text that appears on or just after a line containing a
    /// video-call cue. Returned as-is (custom short-links resolve in-browser).
    static func labeledURL(in text: String) -> URL? {
        var window = 0
        for line in text.components(separatedBy: .newlines) {
            let lower = line.lowercased()
            if videoCallCues.contains(where: { lower.contains($0) }) { window = 3 }
            if window > 0, let url = firstURL(in: line) { return url }
            if window > 0 { window -= 1 }
        }
        return nil
    }

    /// First http(s) URL in a string, via the system link detector.
    private static func firstURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var result: URL?
        detector.enumerateMatches(in: text, options: [], range: range) { match, _, stop in
            if let url = match?.url, url.scheme?.hasPrefix("http") == true {
                result = url
                stop.pointee = true
            }
        }
        return result
    }

    /// Returns the (possibly unwrapped) URL if it points at a conferencing
    /// host, else nil.
    static func conferencingURL(from url: URL) -> URL? {
        let resolved = unwrap(url)
        return isConferencing(resolved) ? resolved : nil
    }

    static func isConferencing(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return conferencingHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// Unwrap a link-protection / tracking redirect to its inner target.
    private static func unwrap(_ url: URL) -> URL {
        guard let host = url.host?.lowercased(),
              redirectHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }),
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return url }
        for key in ["url", "q", "u"] {
            if let value = comps.queryItems?.first(where: { $0.name == key })?.value,
               let inner = URL(string: value), inner.host != nil {
                return inner
            }
        }
        return url
    }

    /// Extract every link in the text (via the system link detector) and return
    /// the first one that resolves to a conferencing host.
    static func firstConferencingURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var result: URL?
        detector.enumerateMatches(in: text, options: [], range: range) { match, _, stop in
            if let url = match?.url, let c = conferencingURL(from: url) {
                result = c
                stop.pointee = true
            }
        }
        return result
    }

    /// A short human label for the provider, for the Join button.
    static func providerName(for url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        if host.contains("zoom") { return "Zoom" }
        if host.contains("meet.google.com") { return "Google Meet" }
        if host.contains("teams.") { return "Teams" }
        if host.contains("webex.com") { return "Webex" }
        if host.contains("whereby.com") { return "Whereby" }
        if host.contains("gotomeet") { return "GoToMeeting" }
        if host.contains("bluejeans") { return "BlueJeans" }
        if host.contains("jit.si") { return "Jitsi" }
        if host.contains("chime.aws") { return "Chime" }
        return "Meeting"
    }
}

extension NSColor {
    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#4C8BF5" }
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
