import Foundation
import WhisperKit

enum DictationState {
    case idle
    case recording
    case handsFree
}

/// Wires the hotkey, recorder, transcription, and paste injection together.
final class DictationController {
    var onStateChange: ((DictationState) -> Void)?
    /// Smoothed mic level (0...1), emitted while recording.
    var onLevel: ((Float) -> Void)?
    /// Fired on the main thread after each successful transcription.
    var onSession: ((Double, String) -> Void)?

    private let hotkey = HotkeyMonitor()
    private let recorder = AudioRecorder()
    private var whisper: WhisperKit?
    private var loading = true
    private var recording = false
    private var handsFree = false

    private var streamer: StreamingTranscriber?
    private var streamPumpTask: Task<Void, Never>?

    func start() {
        Task { await loadModel() }

        hotkey.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .startRecord(let asHandsFree):
                self.beginRecording(handsFree: asHandsFree)
            case .stopRecord(let transcribe):
                self.endRecording(transcribe: transcribe)
            }
        }
        recorder.onLevel = { [weak self] peak in
            // Mic peaks are typically small (<0.3 even when speaking loudly);
            // scale + clamp so the meter actually fills the symbol.
            let scaled = min(1, peak * 6)
            DispatchQueue.main.async { self?.onLevel?(scaled) }
        }
        hotkey.start()
    }

    private func loadModel() async {
        do {
            // `large-v3_turbo` is the speed/quality sweet spot on Apple Silicon.
            // First launch downloads ~600MB to ~/Documents/huggingface/.
            whisper = try await WhisperKit(model: "large-v3_turbo")
            fputs("Whisper model loaded — pre-warming...\n", stderr)

            // Run a 1s silent buffer through transcribe so Core ML compiles
            // its kernels now, instead of on the user's first real hotkey press.
            let silent = [Float](repeating: 0, count: 16_000)
            _ = try? await whisper?.transcribe(audioArray: silent)
            fputs("Pre-warm complete. Ready.\n", stderr)
            loading = false
        } catch {
            fputs("Failed to load Whisper model: \(error)\n", stderr)
        }
    }

    private func beginRecording(handsFree asHandsFree: Bool) {
        guard !loading, !recording, let whisper else { return }
        do {
            try recorder.start()
            recording = true
            handsFree = asHandsFree
            onStateChange?(asHandsFree ? .handsFree : .recording)

            // Spin up a streaming transcriber and a pump that periodically
            // hands it the current buffer. The actor processes each completed
            // 20s chunk while we're still recording.
            let streamer = StreamingTranscriber(whisper: whisper)
            self.streamer = streamer
            streamPumpTask = Task { [recorder] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if Task.isCancelled { break }
                    await streamer.extend(buffer: recorder.snapshot())
                }
            }
        } catch {
            fputs("recorder.start error: \(error)\n", stderr)
        }
    }

    private func endRecording(transcribe: Bool) {
        guard recording else { return }
        recording = false
        handsFree = false
        onStateChange?(.idle)

        streamPumpTask?.cancel()
        streamPumpTask = nil
        let samples = recorder.stop()
        let streamer = self.streamer
        self.streamer = nil

        guard transcribe else { return }
        let peak = samples.map { abs($0) }.max() ?? 0
        fputs("captured \(samples.count) samples (~\(samples.count / 16000)s), peak=\(peak)\n", stderr)
        guard samples.count > 1600 else {
            fputs("too short — skipping\n", stderr)
            return
        }

        Task { await finalizeAndPaste(samples: samples, streamer: streamer) }
    }

    private func finalizeAndPaste(samples: [Float], streamer: StreamingTranscriber?) async {
        guard let streamer else { return }
        let text = await streamer.finalize(buffer: samples)
        fputs("transcript: \"\(text)\"\n", stderr)
        guard !text.isEmpty else { return }
        let audioSeconds = Double(samples.count) / 16_000
        await MainActor.run {
            TextInjector.paste(text)
            self.onSession?(audioSeconds, text)
        }
    }
}
