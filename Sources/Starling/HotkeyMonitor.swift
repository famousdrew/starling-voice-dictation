import AppKit
import Carbon.HIToolbox

enum HotkeyEvent {
    case startRecord(handsFree: Bool)
    case stopRecord(transcribe: Bool)
}

/// Watches Right Option for two gestures:
/// - **Hold**: press, speak, release → transcribe.
/// - **Double-tap**: two quick taps with no real audio → enter hands-free
///   mode, recording continues until any other key is pressed (which is
///   suppressed).
final class HotkeyMonitor {
    var onEvent: ((HotkeyEvent) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let targetKeyCode: CGKeyCode = 61 // kVK_RightOption

    /// A Right Option press shorter than this is considered a tap (no audio yet).
    private let tapMaxDuration: CFTimeInterval = 0.25
    /// Two taps must end within this window to count as a double-tap.
    private let doubleTapWindow: CFTimeInterval = 0.35

    private var pressStartTime: CFTimeInterval = 0
    private var lastTapEndTime: CFTimeInterval = 0
    private var isHeld = false
    private var isHandsFree = false
    /// When we exit hands-free mode (via Right Option or Escape), the matching
    /// release/keyUp arrives a moment later — ignore it so it doesn't start a
    /// fresh recording or otherwise confuse the state machine.
    private var ignoreNextRightOptionEvent = false

    func start() {
        // We listen for both modifier changes (Right Option) and key-down (to
        // terminate hands-free mode). `defaultTap` (not `listenOnly`) lets us
        // return nil from the callback to suppress the terminating keystroke.
        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            fputs("Failed to create event tap. Grant Input Monitoring permission.\n", stderr)
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The event tap occasionally gets disabled by the system (timeout,
        // event flood). Re-enable and pass the event through.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        if type == .flagsChanged, keyCode == targetKeyCode {
            handleRightOption()
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown, isHandsFree {
            // Escape cancels (no transcription); any other key ends the
            // session and transcribes. Either way, swallow the key so it
            // doesn't land as a stray character in the focused app.
            let isEscape = keyCode == CGKeyCode(kVK_Escape)
            isHandsFree = false
            onEvent?(.stopRecord(transcribe: !isEscape))
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleRightOption() {
        let now = CACurrentMediaTime()

        if ignoreNextRightOptionEvent {
            ignoreNextRightOptionEvent = false
            return
        }

        if isHandsFree {
            // Tap Right Option again to stop and transcribe. (Use Escape to cancel.)
            isHandsFree = false
            // The matching key release will fire .flagsChanged again — skip it
            // so it doesn't get interpreted as the start of a new recording.
            ignoreNextRightOptionEvent = true
            onEvent?(.stopRecord(transcribe: true))
            return
        }

        if !isHeld {
            // Press
            isHeld = true
            pressStartTime = now
            onEvent?(.startRecord(handsFree: false))
        } else {
            // Release
            isHeld = false
            let duration = now - pressStartTime
            if duration < tapMaxDuration {
                // A tap. Discard the (very short) audio.
                onEvent?(.stopRecord(transcribe: false))
                if now - lastTapEndTime < doubleTapWindow {
                    // Second tap of a double-tap → enter hands-free mode.
                    lastTapEndTime = 0
                    isHandsFree = true
                    onEvent?(.startRecord(handsFree: true))
                } else {
                    lastTapEndTime = now
                }
            } else {
                // Normal hold release → transcribe.
                lastTapEndTime = 0
                onEvent?(.stopRecord(transcribe: true))
            }
        }
    }
}
