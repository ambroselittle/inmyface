import SwiftUI

/// The full-screen takeover content. Big, unmissable, dark, with the actions.
struct OverlayView: View {
    let meeting: Meeting
    let snoozeMinutes: Int
    let onJoin: () -> Void
    let onSnooze: () -> Void
    let onDismiss: () -> Void

    private var accent: Color { Color(hex: meeting.calendarColor) ?? .blue }

    var body: some View {
        ZStack {
            // Dimmed backdrop with a subtle accent glow.
            LinearGradient(
                colors: [Color.black.opacity(0.96), Color(hex: meeting.calendarColor)?.opacity(0.22) ?? .black.opacity(0.9)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Text(startLine)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))

                Text(meeting.title)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 60)

                // Live countdown.
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(countdown)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(accent)
                        .contentTransition(.numericText())
                }

                HStack(spacing: 16) {
                    Label(meeting.calendarTitle, systemImage: "calendar")
                    if let loc = meeting.location {
                        Label(loc, systemImage: "mappin.and.ellipse")
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

                Spacer()

                HStack(spacing: 20) {
                    if let url = meeting.joinURL {
                        ActionButton(
                            title: "Join \(MeetingLink.providerName(for: url))",
                            systemImage: "video.fill",
                            tint: accent,
                            prominent: true,
                            action: onJoin
                        )
                        .keyboardShortcut(.defaultAction)
                    }
                    ActionButton(
                        title: "Snooze \(snoozeMinutes) min",
                        systemImage: "moon.zzz.fill",
                        tint: .white.opacity(0.16),
                        prominent: false,
                        action: onSnooze
                    )
                    ActionButton(
                        title: "Dismiss",
                        systemImage: "xmark",
                        tint: .white.opacity(0.16),
                        prominent: false,
                        action: onDismiss
                    )
                    .keyboardShortcut(.cancelAction)
                }
                .padding(.bottom, 60)
            }
        }
    }

    private var startLine: String {
        let mins = meeting.minutesUntilStart
        let df = DateFormatter()
        df.timeStyle = .short
        let at = df.string(from: meeting.start)
        if mins > 0 { return "Starts in \(mins) min · \(at)" }
        if mins == 0 { return "Starting now · \(at)" }
        return "Started \(-mins) min ago · \(at)"
    }

    private var countdown: String {
        let secs = Int(meeting.start.timeIntervalSinceNow)
        let sign = secs < 0 ? "-" : ""
        let a = abs(secs)
        return String(format: "%@%02d:%02d", sign, a / 60, a % 60)
    }
}

private struct ActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let prominent: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(prominent ? .white : .white.opacity(0.95))
                .padding(.horizontal, 30)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(hovering ? 1.0 : (prominent ? 0.9 : 1.0)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(prominent ? 0 : 0.12), lineWidth: 1)
                )
                .scaleEffect(hovering ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

extension Color {
    /// Init from "#RRGGBB".
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        self = Color(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }
}
