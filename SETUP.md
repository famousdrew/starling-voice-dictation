# Starling for Windows — Setup Guide

Starling is a push-to-talk dictation tool. Hold **Right Ctrl** to record, release to transcribe and paste into whatever app has focus.

## Requirements

- Windows 10 or 11
- Python **3.12** (not 3.13 or 3.14 — a NeMo dependency blocks them)
- An NVIDIA GPU with CUDA 12.8+ recommended (works on CPU but will be slow)
- ~6 GB free disk space for dependencies + the Parakeet model

## Quick setup

```powershell
git clone https://github.com/famousdrew/starling.git
cd starling
.\setup.ps1
```

`setup.ps1` will:
1. Verify Python 3.12 is available
2. Create an isolated `.venv`
3. Install PyTorch with CUDA support
4. Install all other dependencies

If you don't have Python 3.12:
```powershell
winget install Python.Python.3.12
```

## Running

```powershell
.\run.ps1
```

The Parakeet speech model (~2.5 GB) downloads automatically on first run and is cached for future launches. Startup takes 15–30 seconds while the model loads.

## Usage

| Gesture | Action |
|---|---|
| Hold Right Ctrl | Record — release to transcribe + paste |
| Double-tap Right Ctrl | Hands-free mode — keeps recording until any key |
| Right Ctrl (in hands-free) | Stop + transcribe + paste |
| Escape (in hands-free) | Cancel without pasting |

The transcribed text is pasted at your cursor in whatever app currently has focus.

## Tray icon

Starling runs in the system tray (bottom-right, may be in the overflow `^` menu).
Right-click the icon to open the Stats window or quit.

## Custom vocabulary

If Starling mishears product names or jargon, add corrections to:

```
%APPDATA%\Starling\corrections.json
```

Format — key is what the model says (lowercase), value is what gets pasted:

```json
{
  "you attend": "uAttend",
  "work well": "Workwell"
}
```

Changes take effect immediately — no restart needed.

## Launch at login

Open the Stats window → Settings tab → Enable launch at login.

## Troubleshooting

**Hotkey does nothing after "Pre-warm complete. Ready."**
Check Windows Settings → Privacy & Security → Microphone → allow desktop app access.

**Transcription is very slow**
CUDA isn't being used. Run:
```powershell
.venv\Scripts\python.exe -c "import torch; print(torch.cuda.is_available())"
```
If it prints `False`, re-run `setup.ps1` — it may have installed CPU-only PyTorch.

**App won't start / crashes on launch**
Make sure you're running from the repo root with `.\run.ps1`, not directly with `python`.
