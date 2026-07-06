import Foundation
import EventKit
import AppKit

/// Extracts a join URL from a calendar event, checking the structured URL,
/// then the notes/body, then the location field.
enum MeetingLink {
    /// Ordered so the most specific / most common providers win.
    private static let patterns: [String] = [
        #"https://[a-z0-9-]+\.zoom\.us/j/[^\s<>"')]+"#,
        #"https://[a-z0-9-]*\.?zoom\.us/[^\s<>"')]+"#,
        #"https://meet\.google\.com/[a-z0-9-]+"#,
        #"https://teams\.microsoft\.com/l/meetup-join/[^\s<>"')]+"#,
        #"https://teams\.live\.com/meet/[^\s<>"')]+"#,
        #"https://[a-z0-9-]+\.webex\.com/[^\s<>"')]+"#,
        #"https://[a-z0-9-]+\.whereby\.com/[^\s<>"')]+"#,
        #"https://app\.gather\.town/[^\s<>"')]+"#,
        #"https://[a-z0-9-]+\.around\.co/[^\s<>"')]+"#,
    ]

    static func find(in event: EKEvent) -> URL? {
        // 1. Structured URL field (Google Calendar populates this for Meet).
        if let url = event.url, isMeetingURL(url.absoluteString) {
            return url
        }
        // 2. Notes / body.
        if let notes = event.notes, let url = firstMatch(in: notes) {
            return url
        }
        // 3. Location field (sometimes holds the Zoom/Meet link).
        if let loc = event.location, let url = firstMatch(in: loc) {
            return url
        }
        // 4. Fallback: any URL field at all (e.g. a generic https link).
        if let url = event.url { return url }
        return nil
    }

    private static func isMeetingURL(_ s: String) -> Bool {
        firstMatch(in: s) != nil
    }

    static func firstMatch(in text: String) -> URL? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let r = Range(match.range, in: text) {
                var str = String(text[r])
                // Trim trailing punctuation that regex may have grabbed.
                while let last = str.last, ")].,>\"'".contains(last) {
                    str.removeLast()
                }
                if let url = URL(string: str) { return url }
            }
        }
        return nil
    }

    /// A short human label for the provider, for the Join button.
    static func providerName(for url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        if host.contains("zoom.us") { return "Zoom" }
        if host.contains("meet.google.com") { return "Google Meet" }
        if host.contains("teams.") { return "Teams" }
        if host.contains("webex.com") { return "Webex" }
        if host.contains("whereby.com") { return "Whereby" }
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
