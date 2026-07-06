import AppKit

// Menubar-only app: no storyboard, no @main, explicit lifecycle so we control
// activation policy and keep everything in one executable target.
// Top-level code runs on the main thread; assert that to satisfy the
// main-actor isolation of AppDelegate under Swift 6.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
