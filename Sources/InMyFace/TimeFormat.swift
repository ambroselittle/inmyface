import Foundation

/// Human-friendly time formatting shared by the overlay and the menu.
enum TimeFormat {
    /// Big ticking countdown. Under an hour it's MM:SS (so the seconds tick
    /// near start); further out it rolls up to hours, then days.
    static func countdown(to date: Date) -> String {
        let total = Int(date.timeIntervalSinceNow)
        let past = total < 0
        let s = abs(total)
        let body: String
        if s >= 86_400 {
            body = "\(s / 86_400)d \((s % 86_400) / 3_600)h"
        } else if s >= 3_600 {
            body = "\(s / 3_600)h \((s % 3_600) / 60)m"
        } else {
            body = String(format: "%02d:%02d", s / 60, s % 60)
        }
        return past ? "-\(body)" : body
    }

    /// Compact relative phrase: "now", "in 5 min", "in 2h 15m", "1d 3h ago".
    static func relative(to date: Date) -> String {
        let total = Int(date.timeIntervalSinceNow.rounded())
        if total <= 0 && total > -60 { return "now" }
        let past = total < 0
        let s = abs(total)
        let phrase: String
        if s >= 86_400 {
            let d = s / 86_400, h = (s % 86_400) / 3_600
            phrase = h > 0 ? "\(d)d \(h)h" : "\(d)d"
        } else if s >= 3_600 {
            let h = s / 3_600, m = (s % 3_600) / 60
            phrase = m > 0 ? "\(h)h \(m)m" : "\(h)h"
        } else {
            phrase = "\(max(1, s / 60)) min"
        }
        return past ? "\(phrase) ago" : "in \(phrase)"
    }

    /// Very short form for the menubar title: "now", "5m", "2h15m", "1d".
    static func menubar(to date: Date) -> String {
        let total = Int(date.timeIntervalSinceNow.rounded())
        if total <= 0 { return "now" }
        if total >= 86_400 { return "\(total / 86_400)d" }
        if total >= 3_600 {
            let h = total / 3_600, m = (total % 3_600) / 60
            return m > 0 ? "\(h)h\(m)m" : "\(h)h"
        }
        return "\(max(1, total / 60))m"
    }

    /// Wall-clock time, e.g. "3:45 PM".
    static func clock(_ date: Date) -> String {
        let df = DateFormatter()
        df.timeStyle = .short
        return df.string(from: date)
    }
}
