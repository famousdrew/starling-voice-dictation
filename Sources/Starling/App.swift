import AppKit
import SwiftUI

@main
struct StarlingApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let controller = DictationController()
    private let stats = SessionStats()
    private let corrections = Corrections()
    private let liveTranscripts = LiveTranscripts()
    private lazy var statsWindow = StatsWindowController(
        stats: stats,
        corrections: corrections,
        liveTranscripts: liveTranscripts
    )
    private let splash = SplashWindowController()

    private var state: DictationState = .idle
    private var displayedLevel: Float = 0
    private var levelTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        renderIcon()

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Hold Right Option to Dictate", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Double-tap Right Option for Hands-Free", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        let statsItem = NSMenuItem(title: "Stats", action: #selector(showStats), keyEquivalent: "")
        statsItem.target = self
        menu.addItem(statsItem)

        let dictItem = NSMenuItem(title: "Dictionary", action: #selector(showDictionary), keyEquivalent: "")
        dictItem.target = self
        menu.addItem(dictItem)

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu

        controller.corrections = corrections
        controller.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.state = state
                if state == .idle { self?.displayedLevel = 0 }
                self?.renderIcon()
            }
        }
        controller.onSession = { [weak self] audioSeconds, transcript in
            self?.stats.record(audioSeconds: audioSeconds, transcript: transcript)
            self?.liveTranscripts.append(transcript)
        }
        controller.onLevel = { [weak self] level in
            // Asymmetric smoothing: snap up fast, decay slow — same trick
            // GarageBand-style level meters use to feel responsive.
            guard let self else { return }
            if level > self.displayedLevel {
                self.displayedLevel = level
            } else {
                self.displayedLevel = self.displayedLevel * 0.7 + level * 0.3
            }
        }
        controller.onStatus = { [weak self] message in
            self?.splash.setStatus(message)
        }
        controller.onReady = { [weak self] in
            self?.splash.finish()
        }

        // Repaint at 20Hz while recording so smoothing decay is visible even
        // during silence.
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.state != .idle else { return }
                self.renderIcon()
            }
        }

        splash.show()
        controller.start()
    }

    private func renderIcon() {
        guard let button = statusItem.button else { return }

        switch state {
        case .idle:
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Starling")
            button.contentTintColor = nil
        case .recording:
            button.image = LevelMeterIcon.image(level: displayedLevel, tint: .labelColor)
            button.contentTintColor = nil
        case .handsFree:
            button.image = LevelMeterIcon.image(level: displayedLevel, tint: .systemRed)
            button.contentTintColor = nil
        }
    }

    @objc private func showStats() { statsWindow.show(tab: .overview) }
    @objc private func showDictionary() { statsWindow.show(tab: .vocabulary) }
    @objc private func showSettings() { statsWindow.show(tab: .settings) }
    @objc private func quit() { NSApp.terminate(nil) }
}
