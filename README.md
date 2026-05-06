# Starling

**Free, offline, push-to-talk dictation for Windows and macOS.** Hold a key, speak, release. Your words appear instantly at the cursor in any app. No cloud. No subscription. No audio ever leaves your machine.

[![Platform: Windows](https://img.shields.io/badge/platform-Windows%2010%2F11-blue?logo=windows)](#windows)
[![Platform: macOS](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey?logo=apple)](#macos)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](#license)
[![Model: Parakeet-TDT v3](https://img.shields.io/badge/model-Parakeet--TDT%20v3-76b900?logo=nvidia)](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)

---

## Why Starling?

Most dictation tools are cloud services. Your voice goes to a server, gets transcribed, comes back. That means latency, a monthly bill, and someone else's infrastructure between you and your words.

Starling runs entirely on your hardware. On a modern GPU it transcribes faster than real-time, with accuracy that rivals or beats cloud alternatives on English. It works in every app: your browser, your IDE, your email client, your Slack. It pastes at the cursor just like you typed it.

**It's also completely free and open source.**

---

## Features

- **Hold-to-talk:** hold the hotkey, speak naturally, release to paste. Works in any focused window.
- **Hands-free mode:** double-tap the hotkey to lock recording on. Any key ends and transcribes; Escape cancels cleanly.
- **Streaming transcription:** audio is split at natural silences and processed in the background while you're still talking. Release-to-paste latency stays tight even on long sessions.
- **Live level meter:** the tray/menubar icon animates with your mic input so you always know when you're being heard.
- **Stats window:** words today, last 7 days, and lifetime; average speaking WPM; 30-day chart; recent session history; paste playground.
- **Custom vocabulary:** teach Starling your product names, acronyms, and jargon via a simple JSON file. No retraining required.
- **Launch at login:** one toggle and it's always ready in the background.
- **Fully offline:** transcription runs locally. Audio never leaves your machine.

---

## Platform support

| | Windows 10/11 | macOS 14+ (Sonoma) |
|---|---|---|
| **Branch** | `main` | [`macos-swift`](https://github.com/famousdrew/starling/tree/macos-swift) |
| **Language** | Python | Swift |
| **Model** | Parakeet-TDT v3 (NVIDIA NeMo) | Whisper large-v3-turbo (WhisperKit) |
| **Hotkey** | Right Ctrl | Right Option |
| **GPU** | NVIDIA CUDA | Apple Neural Engine |

---

## Windows

### Requirements

- Windows 10 or 11
- **Python 3.12** specifically. Versions 3.13 and 3.14 are blocked by a NeMo dependency.
- NVIDIA GPU with CUDA 12.8+ strongly recommended. CPU mode works but is too slow for real-time use.
- ~6 GB free disk space for dependencies and the Parakeet model.

### Quick start

```powershell
git clone https://github.com/famousdrew/starling.git
cd starling
.\setup.ps1
.\run.ps1
```

`setup.ps1` handles everything: creates a Python 3.12 virtual environment, installs PyTorch with CUDA support in the correct order, and installs all dependencies. Run it once. After that, use `run.ps1` to launch, or enable **Launch at Login** in the Settings tab to have it start automatically.

The [Parakeet-TDT v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) model (~2.5 GB) downloads automatically on first run and is cached locally.

> Don't have Python 3.12?
> ```powershell
> winget install Python.Python.3.12
> ```

### Usage

| Gesture | Action |
|---|---|
| Hold **Right Ctrl** | Record while held, then release to transcribe and paste |
| **Double-tap** Right Ctrl | Hands-free mode, keeps recording until you stop it |
| Right Ctrl *(in hands-free)* | Stop, transcribe, and paste |
| Any other key *(in hands-free)* | Stop, transcribe, paste, then send the key |
| **Escape** *(in hands-free)* | Cancel without pasting |

### Custom vocabulary

Starling ships with a vocabulary file tuned for common mishearings. To add your own corrections, edit:

```
%APPDATA%\Starling\corrections.json
```

The key is what the model hears (lowercase), the value is what gets pasted:

```json
{
  "you attend": "uAttend",
  "work well": "Workwell",
  "my product": "MyProduct"
}
```

Changes take effect immediately with no restart needed.

### Full setup guide

See **[SETUP.md](SETUP.md)** for detailed instructions, troubleshooting, and notes on running without a CUDA GPU.

---

## macOS

The macOS version lives on the [`macos-swift`](https://github.com/famousdrew/starling/tree/macos-swift) branch. It's a native Swift app built on AVAudioEngine and [WhisperKit](https://github.com/argmaxinc/WhisperKit), optimised for Apple Silicon.

### Requirements

- macOS 14 Sonoma or later
- Xcode Command Line Tools (`xcode-select --install`)
- Apple Silicon recommended (Intel works, transcription is slower)
- ~700 MB disk for the Whisper model

### Quick start

```sh
git clone -b macos-swift https://github.com/famousdrew/starling.git
cd starling
./build-app.sh
open Starling.app
```

The Whisper `large-v3-turbo` model (~600 MB) downloads on first run.

### Permissions

macOS will prompt for three permissions on first use:

| Permission | Used for |
|---|---|
| Microphone | Audio capture |
| Input Monitoring | Global hotkey via `CGEventTap` |
| Accessibility | Synthesizing `Cmd+V` to paste |

All three are required. Grant them in **System Settings > Privacy & Security** if the prompts don't appear automatically.

### Usage

| Gesture | Action |
|---|---|
| Hold **Right Option** | Record, then release to transcribe and paste |
| Double-tap Right Option | Hands-free mode |
| Right Option *(in hands-free)* | Stop and paste |
| Escape *(in hands-free)* | Cancel |

---

## How it works

Starling buffers microphone audio at 16 kHz mono Float32. While you're recording, a background thread scans for silence boundaries (peak amplitude below 0.012 over 400ms) to split audio into 8-25 second chunks, which are transcribed as they complete. When you release the hotkey, any remaining audio is drained and all partial transcripts are joined. The result is saved to clipboard, `Ctrl+V` (or `Cmd+V`) is synthesised, and your previous clipboard is restored 150ms later.

This chunked streaming approach means a 60-second dictation doesn't make you wait 60 seconds. Most of the transcript is ready before you even release the key.

---

## Privacy

- Audio is processed entirely on-device. Nothing is sent to any server.
- Session statistics (word counts, transcripts) are stored locally at `%APPDATA%\Starling\stats.json` (Windows) or `~/Library/Application Support/Starling/stats.json` (macOS).
- No telemetry, no analytics, no accounts.

---

## License

MIT. Use it, fork it, ship it to your team.

---

> *Named after the bird: a flock of starlings is called a murmuration, and starlings are remarkable vocal mimics.*
