import Foundation
import simd

/// Movement-units smoothness: prominent speed peaks per meter of path.
/// A smooth arm movement has one or two; a jerky one has many.
enum Smoothness {
    /// ~150ms at 60Hz.
    static let window = 9
    /// A peak only counts if speed rose this fraction of the max above the preceding valley.
    static let prominence: Float = 0.1
    static let idealPeaksPerMeter: Float = 2
    static let worstPeaksPerMeter: Float = 12

    static func peaksPerMeter(samples: [Sample]) -> Float {
        let pathLength = Resample.pathLength(samples.map(\.position))
        guard pathLength > 0.05 else { return worstPeaksPerMeter }
        let speeds = speedProfile(samples)
        let smoothed = movingAverage(speeds, window: window)
        return Float(countPeaks(smoothed)) / pathLength
    }

    static func score(peaksPerMeter: Float) -> Float {
        let range = worstPeaksPerMeter - idealPeaksPerMeter
        return min(1, max(0, 1 - (peaksPerMeter - idealPeaksPerMeter) / range))
    }

    private static func speedProfile(_ samples: [Sample]) -> [Float] {
        zip(samples, samples.dropFirst()).compactMap { a, b in
            let dt = Float(b.time - a.time)
            guard dt > 0 else { return nil }
            return simd_distance(a.position, b.position) / dt
        }
    }

    private static func movingAverage(_ values: [Float], window: Int) -> [Float] {
        guard values.count > window else { return values }
        let half = window / 2
        return values.indices.map { i in
            let lo = max(0, i - half)
            let hi = min(values.count - 1, i + half)
            return values[lo...hi].reduce(0, +) / Float(hi - lo + 1)
        }
    }

    /// Counts maxima that rise at least `prominence * max` above the lowest
    /// point since the previous counted peak.
    private static func countPeaks(_ values: [Float]) -> Int {
        guard values.count >= 3, let maxValue = values.max(), maxValue > 0 else { return 1 }
        let threshold = maxValue * prominence
        var peaks = 0
        var valley = values[0]
        var climbing = false
        for i in 1..<values.count {
            let v = values[i]
            if v < valley || !climbing {
                valley = min(valley, v)
            }
            if !climbing, v - valley >= threshold {
                climbing = true
                peaks += 1
            } else if climbing, v < values[i - 1], values[i - 1] - v >= threshold {
                climbing = false
                valley = v
            }
        }
        return max(1, peaks)
    }
}
