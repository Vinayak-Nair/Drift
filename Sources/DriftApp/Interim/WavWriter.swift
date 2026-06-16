import Foundation

// INTERIM ONLY. Writes 16 kHz mono Float samples to a temp 16-bit PCM WAV file
// (the format whisper.cpp expects). Shared by the whisper.cpp transcribers.
enum WavWriter {
    static func write(samples: [Float], sampleRate: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("drift-\(UUID().uuidString).wav")

        var pcm = [Int16](); pcm.reserveCapacity(samples.count)
        for s in samples { pcm.append(Int16(max(-1, min(1, s)) * 32767)) }

        var data = Data()
        let dataSize = pcm.count * 2
        func le<T: FixedWidthInteger>(_ v: T) {
            var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
        }
        data.append("RIFF".data(using: .ascii)!); le(UInt32(36 + dataSize))
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!); le(UInt32(16)); le(UInt16(1)); le(UInt16(1))
        le(UInt32(sampleRate)); le(UInt32(sampleRate * 2)); le(UInt16(2)); le(UInt16(16))
        data.append("data".data(using: .ascii)!); le(UInt32(dataSize))
        pcm.withUnsafeBytes { data.append(contentsOf: $0) }
        try data.write(to: url)
        return url
    }
}
