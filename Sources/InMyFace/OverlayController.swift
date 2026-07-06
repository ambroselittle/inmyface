import AppKit
import SwiftUI

/// Borderless windows refuse key status by default, which would kill the
/// Enter-to-join / Esc-to-dismiss keyboard shortcuts. Force it.
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Presents the takeover across every screen. The primary screen shows the
/// interactive content; other screens get a matching dim so nothing peeks
/// through on a multi-monitor setup.
@MainActor
final class OverlayController {
    private var windows: [NSWindow] = []
    private(set) var isVisible = false

    func present(meetings: [Meeting],
                 snoozeMinutes: Int,
                 onJoin: @escaping (Meeting) -> Void,
                 onSnooze: @escaping () -> Void,
                 onDismiss: @escaping () -> Void) {
        guard !isVisible, !meetings.isEmpty else { return }
        isVisible = true

        let primary = NSScreen.main ?? NSScreen.screens.first
        for screen in NSScreen.screens {
            let isPrimary = (screen == primary)
            let window = makeWindow(on: screen)
            if isPrimary {
                let root = OverlayView(
                    meetings: meetings,
                    snoozeMinutes: snoozeMinutes,
                    onJoin: { [weak self] meeting in self?.close(); onJoin(meeting) },
                    onSnooze: { [weak self] in self?.close(); onSnooze() },
                    onDismiss: { [weak self] in self?.close(); onDismiss() }
                )
                window.contentView = NSHostingView(rootView: root)
            } else {
                // Secondary screens: solid dim only.
                let dim = NSView()
                dim.wantsLayer = true
                dim.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.94).cgColor
                window.contentView = dim
            }
            windows.append(window)
            window.orderFrontRegardless()
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)

        if Preferences.soundEnabled {
            NSSound(named: Preferences.soundName)?.play()
        }
    }

    private func makeWindow(on screen: NSScreen) -> NSWindow {
        let window = KeyableWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.setFrame(screen.frame, display: true)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false
        return window
    }

    func close() {
        guard isVisible else { return }
        isVisible = false
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
    }
}
