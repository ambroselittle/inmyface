import SwiftUI

/// The full-screen takeover. Shows one meeting big and centered, or splits the
/// screen when genuinely-distinct meetings start at the same time.
/// Escape or a click on the backdrop dismisses; Enter joins the primary.
struct OverlayView: View {
    let meetings: [Meeting]
    let snoozeMinutes: Int
    let onJoin: (Meeting) -> Void
    let onSnooze: () -> Void
    let onDismiss: () -> Void

    private var accent: Color { Color(hex: meetings.first?.calendarColor ?? "") ?? .blue }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.96), accent.opacity(0.22)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            if meetings.count <= 1, let meeting = meetings.first {
                single(meeting)
            } else {
                split
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }          // click the backdrop to dismiss
        .onExitCommand { onDismiss() }          // Esc to dismiss
    }

    // MARK: - Single meeting

    private func single(_ meeting: Meeting) -> some View {
        VStack(spacing: 28) {
            Spacer()

            Text(startLine(meeting))
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            Text(meeting.title)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 60)

            Countdown(date: meeting.start, size: 34, color: accent)

            metaRow(meeting)

            Spacer()

            HStack(spacing: 20) {
                joinButton(for: meeting, isDefault: true)
                snoozeButton
                dismissButton
            }
            .padding(.bottom, 60)
        }
    }

    // MARK: - Split (multiple concurrent meetings)

    private var split: some View {
        VStack(spacing: 24) {
            Text("\(meetings.count) meetings starting now")
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 50)

            HStack(spacing: 0) {
                ForEach(Array(meetings.enumerated()), id: \.element.id) { index, meeting in
                    if index > 0 {
                        Divider().overlay(.white.opacity(0.12))
                    }
                    column(meeting, isPrimary: index == firstJoinableIndex)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            HStack(spacing: 20) {
                snoozeButton
                dismissButton
            }
            .padding(.bottom, 50)
        }
    }

    private func column(_ meeting: Meeting, isPrimary: Bool) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Text(startLine(meeting))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Text(meeting.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 24)
            Countdown(date: meeting.start, size: 26, color: Color(hex: meeting.calendarColor) ?? accent)
            metaRow(meeting)
            Spacer()
            if meeting.isJoinable {
                joinButton(for: meeting, isDefault: isPrimary)
            }
            Spacer().frame(height: 8)
        }
        .padding(.horizontal, 12)
    }

    /// Index of the first joinable meeting, so Enter joins the right one.
    private var firstJoinableIndex: Int {
        meetings.firstIndex(where: { $0.isJoinable }) ?? 0
    }

    // MARK: - Shared pieces

    private func metaRow(_ meeting: Meeting) -> some View {
        HStack(spacing: 16) {
            Label(meeting.calendarTitle, systemImage: "calendar")
            if let loc = meeting.location {
                Label(loc, systemImage: "mappin.and.ellipse").lineLimit(1)
            }
        }
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.6))
    }

    @ViewBuilder
    private func joinButton(for meeting: Meeting, isDefault: Bool) -> some View {
        if let url = meeting.joinURL {
            let button = ActionButton(
                title: "Join \(MeetingLink.providerName(for: url))",
                systemImage: "video.fill",
                tint: accent,
                prominent: true,
                action: { onJoin(meeting) }
            )
            if isDefault {
                button.keyboardShortcut(.defaultAction)
            } else {
                button
            }
        }
    }

    private var snoozeButton: some View {
        ActionButton(title: "Snooze \(snoozeMinutes) min", systemImage: "moon.zzz.fill",
                     tint: .white.opacity(0.16), prominent: false, action: onSnooze)
    }

    private var dismissButton: some View {
        ActionButton(title: "Dismiss", systemImage: "xmark",
                     tint: .white.opacity(0.16), prominent: false, action: onDismiss)
            .keyboardShortcut(.cancelAction)
    }

    private func startLine(_ meeting: Meeting) -> String {
        let secs = meeting.start.timeIntervalSinceNow
        let at = TimeFormat.clock(meeting.start)
        if abs(secs) < 60 { return "Starting now · \(at)" }
        return secs > 0 ? "Starts at \(at)" : "Started at \(at)"
    }
}

/// A live MM:SS (rolling up to h/d) countdown to a date.
private struct Countdown: View {
    let date: Date
    let size: CGFloat
    let color: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Text(TimeFormat.countdown(to: date))
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
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
