import Foundation
import simd

/// Movement-units smoothness: prominent speed peaks per meter of path.
/// A smooth arm movement has one or two; a jerky one has many.
enum Smoothness {
    /// ~250ms at 60Hz: long enough to flatten pose jitter, short enough to keep hesitations.
    static let window = 15
    /// A peak only counts if speed rose this fraction of the max above the preceding valley.
    static let prominence: Float = 0.15
    /// Sub-movements last 300ms or more, so a wider window and a higher bar
    /// count whole motions rather than ripples.
    static let movementWindow = 21
    static let movementProminence: Float = 0.3
    static let idealPeaksPerMeter: Float = 2
    static let worstPeaksPerMeter: Float = 12

    static func peaksPerMeter(samples: [Sample]) -> Float {
        let pathLength = Resample.pathLength(samples.map(\.position))
        guard pathLength > 0.05 else { return worstPeaksPerMeter }
        let speeds = speedProfile(samples)
        let smoothed = movingAverage(speeds, window: window)
        return Float(countPeaks(smoothed, prominence: prominence)) / pathLength
    }

    static func score(peaksPerMeter: Float) -> Float {
        let range = worstPeaksPerMeter - idealPeaksPerMeter
        return min(1, max(0, 1 - (peaksPerMeter - idealPeaksPerMeter) / range))
    }

    /// Number of distinct sub-movements across all strokes: one per velocity
    /// peak, so one smooth reach is one unit and a drawing done in pieces
    /// has many. Every stroke counts at least once.
    static func movementUnits(strokes: [Stroke]) -> Int {
        strokes.reduce(0) { count, stroke in
            let smoothed = movingAverage(speedProfile(stroke.samples), window: movementWindow)
            return count + countPeaks(smoothed, prominence: movementProminence)
        }
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
    /// point since the previous peak ended, where a peak ends once speed has
    /// fallen that far below its crest.
    private static func countPeaks(_ values: [Float], prominence: Float) -> Int {
        guard values.count >= 3, let maxValue = values.max(), maxValue > 0 else { return 1 }
        let threshold = maxValue * prominence
        var peaks = 0
        var valley = values[0]
        var crest = values[0]
        var climbing = false
        for v in values.dropFirst() {
            if climbing {
                crest = max(crest, v)
                if crest - v >= threshold {
                    climbing = false
                    valley = v
                }
            } else {
                valley = min(valley, v)
                if v - valley >= threshold {
                    climbing = true
                    crest = v
                    peaks += 1
                }
            }
        }
        return max(1, peaks)
    }
}
