import AppKit
import SwiftUI

/// Presents the takeover across every screen. The primary screen shows the
/// interactive content; other screens get a matching dim so nothing peeks
/// through on a multi-monitor setup.
@MainActor
final class OverlayController {
    private var windows: [NSWindow] = []
    private(set) var isVisible = false

    func present(meeting: Meeting,
                 snoozeMinutes: Int,
                 onJoin: @escaping () -> Void,
                 onSnooze: @escaping () -> Void,
                 onDismiss: @escaping () -> Void) {
        guard !isVisible else { return }
        isVisible = true

        let primary = NSScreen.main ?? NSScreen.screens.first
        for screen in NSScreen.screens {
            let isPrimary = (screen == primary)
            let window = makeWindow(on: screen)
            if isPrimary {
                let root = OverlayView(
                    meeting: meeting,
                    snoozeMinutes: snoozeMinutes,
                    onJoin: { [weak self] in self?.close(); onJoin() },
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
    }

    private func makeWindow(on screen: NSScreen) -> NSWindow {
        let window = NSWindow(
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
