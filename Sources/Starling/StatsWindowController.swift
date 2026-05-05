import AppKit
import SwiftUI

/// Manages the lazily-created stats window. Reuses a single window across
/// open/close so playground text and scroll position survive a hide.
@MainActor
final class StatsWindowController {
    private let stats: SessionStats
    private var window: NSWindow?

    init(stats: SessionStats) {
        self.stats = stats
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: StatsView(stats: stats))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Starling"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 700))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
