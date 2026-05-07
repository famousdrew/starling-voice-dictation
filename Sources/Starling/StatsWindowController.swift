import AppKit
import SwiftUI

@MainActor
final class StatsWindowState: ObservableObject {
    @Published var selectedTab: StatsTab = .overview
}

/// Manages the lazily-created stats window. Reuses a single window across
/// open/close so playground text and scroll position survive a hide.
@MainActor
final class StatsWindowController {
    private let stats: SessionStats
    private let corrections: Corrections
    private let liveTranscripts: LiveTranscripts
    private let state = StatsWindowState()
    private var window: NSWindow?

    init(stats: SessionStats, corrections: Corrections, liveTranscripts: LiveTranscripts) {
        self.stats = stats
        self.corrections = corrections
        self.liveTranscripts = liveTranscripts
    }

    func show(tab: StatsTab = .overview) {
        state.selectedTab = tab

        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let root = StatsRoot(
            stats: stats,
            corrections: corrections,
            liveTranscripts: liveTranscripts,
            state: state
        )
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Starling"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 600))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct StatsRoot: View {
    @ObservedObject var stats: SessionStats
    @ObservedObject var corrections: Corrections
    @ObservedObject var liveTranscripts: LiveTranscripts
    @ObservedObject var state: StatsWindowState

    var body: some View {
        StatsView(
            stats: stats,
            corrections: corrections,
            liveTranscripts: liveTranscripts,
            selection: $state.selectedTab
        )
    }
}
