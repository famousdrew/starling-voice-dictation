# Starling

Local push-to-talk dictation for macOS. Hold a hotkey, speak, release — the transcript pastes into whatever app has focus. No cloud, no subscription, no rewriting passes.

> Named after the bird: a flock is called a *murmuration*, and starlings are remarkable vocal mimics.

Powered by [WhisperKit](https://github.com/argmaxinc/WhisperKit) running `large-v3_turbo` on the Apple Neural Engine. Streaming chunked transcription keeps latency near-instant on release even for long sessions.

## Features

- **Hold-to-talk** — hold Right Option, speak, release.
- **Hands-free mode** — double-tap Right Option to lock recording on; any key ends and transcribes (Escape cancels).
- **Streaming transcription** — audio is chunked at natural pauses and transcribed in the background, so release-to-paste latency is bounded by the trailing chunk.
- **Live level meter** — menubar icon shows mic input as five animated bars; red tint while hands-free.
- **Stats window** — words today / 7-day / lifetime, average WPM, 30-day chart, recent sessions, test playground.
- **Launch at Login** — toggle in the menubar dropdown.
- **Pre-warm** — Core ML kernels compile at launch on a silent buffer so your first hotkey press isn't slow.

## Requirements

- macOS 14+ (Sonoma) — uses Swift Charts and SwiftUI features.
- Xcode Command Line Tools (`xcode-select --install`) for `swift`.
- Apple Silicon recommended (Intel works but transcription is significantly slower).
- ~700MB disk for the model (downloaded once on first run).

## Build & run

```sh
./build-app.sh
open Starling.app
```

`build-app.sh` produces `Starling.app` in the project directory. The first launch downloads the Whisper model to `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/` (one time, ~600MB).

## Permissions

macOS prompts for these on first use. All three are required:

| Permission | Used for | Where to grant |
|---|---|---|
| Microphone | Audio capture | Auto-prompts on first hotkey press |
| Input Monitoring | Global hotkey via `CGEventTap` | System Settings → Privacy & Security → Input Monitoring → add `Starling.app` |
| Accessibility | Synthesizing `Cmd+V` to paste | System Settings → Privacy & Security → Accessibility → add `Starling.app` |

If permissions get stuck or a rebuild invalidates them silently:

```sh
tccutil reset All app.starling
killall Starling
open Starling.app
```

Then re-grant via the prompts and System Settings.

## Usage

| Gesture | Effect |
|---|---|
| Hold Right Option | Record while held; transcribe & paste on release |
| Double-tap Right Option | Enter hands-free mode (red bars in menubar) |
| Tap Right Option (while hands-free) | End and transcribe |
| Any key (while hands-free) | End, transcribe, and swallow that key |
| Escape (while hands-free) | Cancel without transcribing |

Stats live at `~/Library/Application Support/Starling/stats.json`.

> **Note:** Claude Code and similar apps may bind double-tap Right Option globally — disable that shortcut to avoid conflicts.

## Architecture

```
Sources/Starling/
├── App.swift                   # menubar app entry, AppDelegate, status icon
├── HotkeyMonitor.swift         # CGEventTap on Right Option; hold + double-tap state machine
├── AudioRecorder.swift         # AVAudioEngine → 16kHz mono Float32 + live peak callback
├── TextInjector.swift          # clipboard-save → Cmd+V synthesis → clipboard-restore
├── StreamingTranscriber.swift  # actor; VAD-based chunk splitting + sequential transcription
├── DictationController.swift   # glue: hotkey → recorder → streamer → paste → stats
├── LevelMeterIcon.swift        # 5-bar NSImage drawn per repaint tick
├── LoginItem.swift             # SMAppService wrapper for "Launch at Login"
├── SessionStats.swift          # ObservableObject; JSON persistence at ~/Library/Application Support/Starling
├── StatsView.swift             # SwiftUI: stats panel + test playground
└── StatsWindowController.swift # NSWindow host for StatsView
```

## Customization

All tunables live in code; edit and rerun `./build-app.sh`.

| What | Where | Default |
|---|---|---|
| Hotkey | `HotkeyMonitor.targetKeyCode` | `61` (Right Option). `63` = Fn, `58` = Left Option |
| Model | `DictationController.loadModel()` | `large-v3_turbo` (try `small.en` for ~3× speed at slight accuracy cost) |
| Mic sensitivity | `DictationController` `peak * 6` scaler | 6× — raise/lower for more/less bar response |
| Bar threshold bias | `LevelMeterIcon` `* 0.65` factor | 0.65 — smaller = more bars light up |
| Chunk min length | `StreamingTranscriber.minChunkSeconds` | 8s |
| Chunk max length | `StreamingTranscriber.maxChunkSeconds` | 25s |
| Silence threshold | `StreamingTranscriber.silenceThreshold` | 0.012 peak amplitude |
| Silence window | `StreamingTranscriber.silenceMilliseconds` | 400ms |
| Tap window | `HotkeyMonitor.tapMaxDuration` / `doubleTapWindow` | 0.25s / 0.35s |

If you fork this for personal use, change `CFBundleIdentifier` in `Info.plist` to your own (e.g., `dev.yourname.starling`) so TCC permissions are namespaced to you.

## Troubleshooting

**Hotkey works but icon never fills (no audio captured):** Microphone permission missing or system mic muted. Check System Settings → Privacy & Security → Microphone, and confirm input is unmuted in System Settings → Sound → Input.

**Hotkey doesn't fire at all:** Input Monitoring permission for `Starling.app` is missing or stale. Reset and re-grant (see Permissions section).

**Audio captures but nothing pastes:** Accessibility permission missing. The `Cmd+V` synthesis is silently dropped without it.

**Permission already granted but still broken after rebuild:** Ad-hoc signing produces a new code signature on each build; macOS may invalidate the existing grants. Run `tccutil reset All app.starling` and re-grant.

**First transcription after launch is slow:** Pre-warm runs on a silent buffer at startup, but if the app paid for it during recording instead, the first hotkey press is slow. Subsequent presses are fast.

**App "loads" but hotkey does nothing when launched via Finder, works from CLI:** Quarantine attribute on the bundle. Run `xattr -dr com.apple.quarantine Starling.app`, reset TCC, re-grant.

**Double-tap conflicts with another app:** Disable the conflicting binding in that app, or change `HotkeyMonitor.targetKeyCode` to a different key.

**Stats window shows zero:** Stats are recorded going forward only; sessions before the stats feature was added aren't backfilled.

## Files written outside the project

- `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/large-v3_turbo/` — downloaded model (~600MB).
- `~/Library/Application Support/Starling/stats.json` — session history.
- `~/Library/Caches/com.apple.CoreML/` — Core ML compilation cache (managed by macOS).
