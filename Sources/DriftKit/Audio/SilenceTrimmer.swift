import Foundation

/// Trims leading/trailing silence and collapses long internal pauses from 16 kHz
/// mono samples, so the transcriber processes less audio (faster) without
/// changing the spoken words. Conservative: keeps an ~80 ms guard band around
/// speech and preserves pauses up to ~400 ms so words don't merge.
public enum SilenceTrimmer {
    public static func trim(_ samples: [Float], sampleRate: Int = 16_000) -> [Float] {
        let frameLen = max(1, sampleRate / 50) // 20 ms frames
        guard samples.count > frameLen * 5 else { return samples }

        // Per-frame RMS energy.
        var energies: [Float] = []
        energies.reserveCapacity(samples.count / frameLen + 1)
        var i = 0
        while i < samples.count {
            let end = min(i + frameLen, samples.count)
            var sum: Float = 0
            var k = i
            while k < end { sum += samples[k] * samples[k]; k += 1 }
            energies.append((sum / Float(end - i)).squareRoot())
            i += frameLen
        }

        let peak = energies.max() ?? 0
        guard peak > 0 else { return samples }
        let threshold = max(Float(0.005), peak * 0.03)
        let speech = energies.map { $0 > threshold }
        guard let first = speech.firstIndex(of: true),
              let last = speech.lastIndex(of: true) else { return samples }

        let guardFrames = 4    // ~80 ms padding around speech
        let maxGapFrames = 20  // collapse internal silence longer than ~400 ms
        let lo = max(0, first - guardFrames)
        let hi = min(energies.count - 1, last + guardFrames)

        var keep = [Bool](repeating: false, count: energies.count)
        var gap = 0
        for f in lo...hi {
            if speech[f] {
                gap = 0
                keep[f] = true
            } else {
                gap += 1
                if gap <= maxGapFrames { keep[f] = true }
            }
        }

        var out: [Float] = []
        out.reserveCapacity(samples.count)
        for f in 0..<energies.count where keep[f] {
            let start = f * frameLen
            let end = min(start + frameLen, samples.count)
            out.append(contentsOf: samples[start..<end])
        }
        return out.count > frameLen ? out : samples
    }
}
