import Foundation
import WhisperKit

/// Transcribes audio in chunks as recording progresses, so by the time the
/// user releases the hotkey only the trailing partial chunk needs fresh work.
///
/// Chunks are split at natural pauses (silence > ~400ms) once the chunk has
/// reached a minimum length, falling back to a hard cut at the maximum length
/// when the speaker just won't stop talking. This avoids mid-word splits in
/// the typical case.
actor StreamingTranscriber {
    private let whisper: WhisperKit

    private let minChunkSamples: Int
    private let maxChunkSamples: Int
    private let silenceWindowSamples: Int
    private let silenceThreshold: Float

    private var consumed = 0
    private var transcripts: [String] = []

    init(
        whisper: WhisperKit,
        minChunkSeconds: Int = 8,
        maxChunkSeconds: Int = 25,
        silenceMilliseconds: Int = 400,
        silenceThreshold: Float = 0.012
    ) {
        self.whisper = whisper
        self.minChunkSamples = minChunkSeconds * 16_000
        self.maxChunkSamples = maxChunkSeconds * 16_000
        self.silenceWindowSamples = silenceMilliseconds * 16
        self.silenceThreshold = silenceThreshold
    }

    /// Transcribe any complete chunks present in `buffer` that haven't been
    /// consumed yet. Safe to call repeatedly during recording.
    func extend(buffer: [Float]) async {
        while let split = nextSplit(in: buffer) {
            let chunk = Array(buffer[consumed..<split])
            consumed = split
            await transcribe(chunk)
        }
    }

    /// Drain any remaining audio (regardless of length), return the
    /// concatenated transcript.
    func finalize(buffer: [Float]) async -> String {
        await extend(buffer: buffer)
        if buffer.count > consumed {
            let tail = Array(buffer[consumed...])
            if tail.count > 1600 {
                await transcribe(tail)
            }
            consumed = buffer.count
        }
        return transcripts
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Find the next chunk boundary at or after `consumed`, or nil if we
    /// should wait for more audio.
    private func nextSplit(in buffer: [Float]) -> Int? {
        let available = buffer.count - consumed
        if available < minChunkSamples { return nil }
        if available > maxChunkSamples {
            // Speaker hasn't paused — force a cut to keep latency bounded.
            return consumed + maxChunkSamples
        }

        let scanStart = consumed + minChunkSamples
        let scanEnd = buffer.count - silenceWindowSamples
        guard scanEnd > scanStart else { return nil }

        // Step in half-windows so a brief silence isn't missed by
        // straddling two scan windows.
        let step = max(silenceWindowSamples / 2, 1)
        var i = scanStart
        while i <= scanEnd {
            var peak: Float = 0
            for j in i..<(i + silenceWindowSamples) {
                let mag = abs(buffer[j])
                if mag > peak { peak = mag }
            }
            if peak < silenceThreshold {
                // Cut in the middle of the silent window so neither neighbor
                // chunk includes a half-trailing word.
                return i + silenceWindowSamples / 2
            }
            i += step
        }
        return nil
    }

    private func transcribe(_ samples: [Float]) async {
        do {
            let results = try await whisper.transcribe(audioArray: samples)
            let text = results.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { transcripts.append(text) }
        } catch {
            fputs("stream chunk error: \(error)\n", stderr)
        }
    }
}
