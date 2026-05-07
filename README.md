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

**It is completely free and open source.**

---

## Features

- **Hold-to-talk:** hold Right Ctrl, speak naturally, release to paste. Works in any focused window.
- **Hands-free mode:** double-tap the hotkey to lock recording on. Any key ends and transcribes; Escape cancels.
- **Streaming transcription:** audio is chunked at natural silences and transcribed in the background while you talk. Release-to-paste latency stays tight even on long sessions.
- **Live level meter:** the system tray icon animates with your mic input so you always know when you are being heard.
- **Launch splash screen:** shows model loading progress and a "Ready to dictate!" confirmation on startup so you know exactly when the app is live.
- **Stats window:** words today, last 7 days, and lifetime; average speaking WPM; 30-day chart; full session history.
- **Custom vocabulary:** teach Starling your product names and jargon through a built-in UI or a plain JSON file. Changes apply instantly, no restart needed.
- **Settings:** toggle launch at login and quit the app, all from the tray icon right-click menu.
- **Desktop and Start Menu shortcuts:** setup creates shortcuts with the Starling icon so the app is always one click away.
- **Launch at login:** one toggle in Settings and it starts automatically with Windows.
- **Fully offline:** audio never leaves your machine.

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
- **Python 3.12** specifically. Versions 3.13 and 3.14 are blocked by a NeMo dependency (numba).
- NVIDIA GPU with CUDA 12.8+ strongly recommended. CPU mode works but is too slow for real-time use.
- ~6 GB free disk space for dependencies and the Parakeet model.

> Don't have Python 3.12? Install it with:
> ```powershell
> winget install Python.Python.3.12
> ```
> Or download directly from [python.org/downloads](https://www.python.org/downloads/release/python-3129/).

### Quick start

```powershell
git clone https://github.com/famousdrew/starling.git
cd starling
.\setup.ps1
```

That's it. `setup.ps1` handles everything:

1. Locates Python 3.12 on your machine
2. Creates a virtual environment
3. Installs PyTorch with CUDA support (downloads ~2.5 GB)
4. Installs NeMo and all other dependencies (~1 GB)
5. Seeds the custom corrections dictionary into `%APPDATA%\Starling\`
6. Generates the app icon
7. Creates a **Desktop shortcut** and a **Start Menu entry**

After setup, launch from the Desktop shortcut, the Start Menu, or:

```powershell
.\run.ps1
```

The [Parakeet-TDT v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) model (~2.5 GB) downloads automatically on first run and is cached locally at `%USERPROFILE%\.cache\huggingface\`.

### First run

A splash screen appears while the model loads and warms up. When it reads **"Ready to dictate!"** the app is live. The splash closes on its own -- no need to click anything.

### Usage

| Gesture | Action |
|---|---|
| Hold **Right Ctrl** | Record while held, release to transcribe and paste |
| **Double-tap** Right Ctrl | Hands-free mode -- keeps recording until you stop it |
| Right Ctrl *(in hands-free)* | Stop, transcribe, and paste |
| Any other key *(in hands-free)* | Stop, transcribe, paste, then send the key normally |
| **Escape** *(in hands-free)* | Cancel without pasting |

Right-click the tray icon for Stats, Dictionary, Settings, and Quit.

### Custom vocabulary

Open the **Dictionary** tab from the tray icon right-click menu to add corrections through the built-in UI. Or edit the file directly:

```
%APPDATA%\Starling\corrections.json
```

The key is what the model hears (lowercase); the value is what gets pasted:

```json
{
  "you attend": "uAttend",
  "work well": "Workwell",
  "my product": "MyProduct"
}
```

Changes take effect immediately whether you use the UI or edit the file.

### Direct downloads

| What | Link |
|---|---|
| Python 3.12 | [python.org/downloads/release/python-3129](https://www.python.org/downloads/release/python-3129/) |
| Git for Windows | [git-scm.com/download/win](https://git-scm.com/download/win) |
| CUDA 12.8 Toolkit (optional) | [developer.nvidia.com/cuda-12-8-0-download-archive](https://developer.nvidia.com/cuda-12-8-0-download-archive) |
| NVIDIA driver 570+ | [nvidia.com/drivers](https://www.nvidia.com/en-us/drivers/) |

You only need the CUDA Toolkit if you want to verify your CUDA version. The PyTorch CUDA wheels are installed automatically by `setup.ps1` and work with any NVIDIA driver 520+.

### Full setup guide

See **[SETUP.md](SETUP.md)** for step-by-step instructions, troubleshooting, and notes on running without a CUDA GPU.

---

## macOS

The macOS version lives on the [`macos-swift`](https://github.com/famousdrew/starling/tree/macos-swift) branch. It is a native Swift app built on AVAudioEngine and [WhisperKit](https://github.com/argmaxinc/WhisperKit), optimised for Apple Silicon.

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

All three are required. Grant them in **System Settings > Privacy & Security** if the prompts do not appear automatically.

### Usage

| Gesture | Action |
|---|---|
| Hold **Right Option** | Record, then release to transcribe and paste |
| Double-tap Right Option | Hands-free mode |
| Right Option *(in hands-free)* | Stop and paste |
| Escape *(in hands-free)* | Cancel |

---

## How it works

Starling buffers microphone audio at 16 kHz mono Float32. While you are recording, a background thread scans for silence boundaries (peak amplitude below 0.012 over 400ms) to split audio into 8-25 second chunks, which are transcribed as they complete. When you release the hotkey, any remaining audio is drained and all partial transcripts are joined. The result is saved to clipboard, `Ctrl+V` is synthesised, and your previous clipboard is restored 150ms later.

This chunked streaming approach means a 60-second dictation does not make you wait 60 seconds. Most of the transcript is ready before you even let go of the key.

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
