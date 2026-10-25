import Foundation
import simd

/// Spatial tremor: how far the drawn path strays from a locally smoothed
/// version of itself. Uses a Savitzky–Golay quadratic filter, which follows
/// curves and corners without flattening them, so a clean circle scores ~0.
enum Wobble {
    /// Path is resampled to this spacing before filtering.
    static let spacingMeters: Float = 0.01
    /// Half-window in samples (window = 2m+1 samples ≈ 25cm). Wide enough that
    /// tremor-scale ripples (4–12cm) cannot be absorbed by the quadratic fit.
    static let halfWindow = 12
    static let cleanMeters: Float = 0.003
    static let worstMeters: Float = 0.012

    /// RMS deviation in meters.
    static func amplitude(points2D: [SIMD2<Float>]) -> Float {
        let pathLength = Resample.pathLength(points2D)
        let count = max(Int(pathLength / spacingMeters), 2 * halfWindow + 3)
        let path = Resample.evenly(points2D, count: count)
        let smoothed = savitzkyGolay(path, halfWindow: halfWindow)
        let squared = zip(path, smoothed).map { simd_length_squared($0 - $1) }
        return (squared.reduce(0, +) / Float(squared.count)).squareRoot()
    }

    static func score(amplitude: Float) -> Float {
        min(1, max(0, 1 - (amplitude - cleanMeters) / (worstMeters - cleanMeters)))
    }

    static func savitzkyGolay(_ values: [SIMD2<Float>], halfWindow m: Int) -> [SIMD2<Float>] {
        guard values.count > 2 * m + 1 else { return values }
        let fm = Float(m)
        let denominator = (2 * fm - 1) * (2 * fm + 1) * (2 * fm + 3)
        let weights: [Float] = (-m...m).map { i in
            let fi = Float(i)
            return (3 * (3 * fm * fm + 3 * fm - 1) - 15 * fi * fi) / denominator
        }
        return values.indices.map { i in
            var sum = SIMD2<Float>(repeating: 0)
            for (k, w) in weights.enumerated() {
                let j = min(max(i + k - m, 0), values.count - 1)
                sum += values[j] * w
            }
            return sum
        }
    }
}
