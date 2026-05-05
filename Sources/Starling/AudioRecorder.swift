import AVFoundation

/// Captures mic audio at 16kHz mono Float32 — the format Whisper expects.
final class AudioRecorder {
    /// Fires with the peak amplitude (0...1) of each captured buffer.
    var onLevel: ((Float) -> Void)?

    private let engine = AVAudioEngine()
    private var buffer: [Float] = []
    private let bufferQueue = DispatchQueue(label: "whisper.audio.buffer")

    /// Whisper's native sample rate.
    private let targetSampleRate: Double = 16_000

    func start() throws {
        buffer.removeAll(keepingCapacity: true)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "Whisper", code: 1)
        }
        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] inBuffer, _ in
            guard let self, let converter else { return }
            let ratio = targetFormat.sampleRate / inputFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(inBuffer.frameLength) * ratio + 1024)
            guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

            var error: NSError?
            var supplied = false
            converter.convert(to: outBuffer, error: &error) { _, status in
                if supplied {
                    status.pointee = .noDataNow
                    return nil
                }
                supplied = true
                status.pointee = .haveData
                return inBuffer
            }
            if let error {
                fputs("convert error: \(error)\n", stderr)
                return
            }

            let frames = Int(outBuffer.frameLength)
            guard frames > 0, let channel = outBuffer.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: channel, count: frames))
            self.bufferQueue.sync { self.buffer.append(contentsOf: samples) }

            var peak: Float = 0
            for sample in samples {
                let mag = abs(sample)
                if mag > peak { peak = mag }
            }
            self.onLevel?(peak)
        }

        engine.prepare()
        try engine.start()
    }

    /// Stop the engine and return the recorded mono 16kHz samples.
    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return bufferQueue.sync { buffer }
    }

    /// Snapshot the running buffer without stopping. Used by the streaming
    /// transcriber to dispatch chunks while recording is still in progress.
    func snapshot() -> [Float] {
        bufferQueue.sync { buffer }
    }
}
