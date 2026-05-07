import AppKit
import SwiftUI

@MainActor
final class SplashState: ObservableObject {
    @Published var status: String = "Starting up…"
    @Published var ready: Bool = false
}

/// A small floating window shown at launch while WhisperKit is loading
/// (and downloading, on first run). Closes itself after `finish()` is called.
@MainActor
final class SplashWindowController {
    let state = SplashState()
    private var window: NSWindow?

    func show() {
        guard window == nil else { return }
        let view = SplashView(state: state)
        let hosting = NSHostingController(rootView: view)
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.center()
        window.orderFrontRegardless()
        self.window = window
    }

    func setStatus(_ message: String) {
        state.status = message
    }

    func finish() {
        guard window != nil else { return }
        state.ready = true
        state.status = "Ready to dictate!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            self?.fadeOutAndClose()
        }
    }

    private func fadeOutAndClose() {
        guard let window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                window.close()
                self?.window = nil
            }
        })
    }
}

private struct SplashView: View {
    @ObservedObject var state: SplashState

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "mic.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(state.ready ? Color.accentColor : Color.secondary)
            Text("Starling")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(state.status)
                .font(.callout)
                .foregroundStyle(state.ready ? Color.accentColor : Color.secondary)
                .fontWeight(state.ready ? .semibold : .regular)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(width: 360, height: 200)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.separator, lineWidth: 1)
        )
    }
}
