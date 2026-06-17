import AVFoundation
import AudioUnit
import CoreAudio

/// Captures microphone audio and returns 16 kHz mono Float samples, the format
/// WhisperKit's `transcribe(audioArray:)` expects. No temp files involved.
public final class Recorder {
    public enum RecorderError: Error { case engineFailedToStart }

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var samples: [Float] = []
    private let targetSampleRate: Double = 16_000
    private let lock = NSLock()
    private let settings: Settings

    public private(set) var isRecording = false

    /// Optional live tap: called with each freshly converted 16 kHz mono chunk as
    /// it's captured, in addition to being accumulated for the batch result. Used
    /// by streaming transcription. Called on the audio thread.
    public var onSamples: (([Float]) -> Void)?

    public init(settings: Settings = .shared) {
        self.settings = settings
    }

    /// Begins capture. Throws if the audio engine can't start (e.g. mic denied).
    public func start() throws {
        guard !isRecording else { return }
        lock.lock(); samples.removeAll(keepingCapacity: true); lock.unlock()

        let input = engine.inputNode
        try applySelectedInputDevice(to: input)
        let inputFormat = input.outputFormat(forBus: 0)

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else { throw RecorderError.engineFailedToStart }

        converter = AVAudioConverter(from: inputFormat, to: outputFormat)

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.append(buffer: buffer, outputFormat: outputFormat)
        }

        engine.prepare()
        do {
            try engine.start()
            isRecording = true
        } catch {
            input.removeTap(onBus: 0)
            throw RecorderError.engineFailedToStart
        }
    }

    /// Stops capture and returns the captured samples. Returns an empty array if
    /// the clip was too short to be meaningful (< 0.2 s).
    public func stop() -> [Float] {
        guard isRecording else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false

        lock.lock(); let captured = samples; lock.unlock()
        guard captured.count > Int(targetSampleRate * 0.2) else { return [] }
        return captured
    }

    private func append(buffer: AVAudioPCMBuffer, outputFormat: AVAudioFormat) {
        guard let converter else { return }

        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1024)
        guard let out = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }

        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        if error != nil { return }

        guard let channel = out.floatChannelData?[0] else { return }
        let frames = Int(out.frameLength)
        let chunk = Array(UnsafeBufferPointer(start: channel, count: frames))
        lock.lock()
        samples.append(contentsOf: chunk)
        lock.unlock()
        onSamples?(chunk)
    }

    private func applySelectedInputDevice(to input: AVAudioInputNode) throws {
        guard let deviceID = AudioInputDevices.deviceID(for: settings.inputDeviceID) else { return }
        guard let audioUnit = input.audioUnit else { throw RecorderError.engineFailedToStart }

        var mutableDeviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else { throw RecorderError.engineFailedToStart }
    }
}
