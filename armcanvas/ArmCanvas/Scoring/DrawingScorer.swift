import Foundation
import simd

struct DrawingScore: Codable, Equatable {
    let shape: Float
    let size: Float
    let smoothness: Float
    let total: Int
    let extentMeters: Float
    let durationSeconds: Float
    let procrustesDistance: Float
    let peaksPerMeter: Float
    let wobbleMeters: Float
    /// Sub-movements used to make the drawing. 0 for entries saved before this existed.
    let motions: Int
}

extension DrawingScore {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shape = try c.decode(Float.self, forKey: .shape)
        size = try c.decode(Float.self, forKey: .size)
        smoothness = try c.decode(Float.self, forKey: .smoothness)
        total = try c.decode(Int.self, forKey: .total)
        extentMeters = try c.decode(Float.self, forKey: .extentMeters)
        durationSeconds = try c.decode(Float.self, forKey: .durationSeconds)
        procrustesDistance = try c.decode(Float.self, forKey: .procrustesDistance)
        peaksPerMeter = try c.decode(Float.self, forKey: .peaksPerMeter)
        wobbleMeters = try c.decode(Float.self, forKey: .wobbleMeters)
        motions = try c.decodeIfPresent(Int.self, forKey: .motions) ?? 0
    }
}

enum DrawingScorer {
    static let shapeWeight: Float = 0.40
    static let sizeWeight: Float = 0.25
    static let smoothnessWeight: Float = 0.35
    static let wobbleShare: Float = 0.7
    /// Procrustes RMS distance (relative to shape size) treated as perfect.
    static let shapePerfectDistance: Float = 0.03
    /// Distance above perfect at which the shape score reaches zero.
    static let shapeRange: Float = 0.45

    static func score(strokes: [Stroke], template: DrawingTemplate, targetExtentMeters: Float? = nil) -> DrawingScore? {
        let targetExtent = targetExtentMeters ?? template.targetExtentMeters
        let samples = strokes.flatMap(\.samples)
        guard samples.count >= 4 else { return nil }
        let positions = samples.map(\.position)

        let projection = PlaneProjection(points: positions)
        let resampled = Resample.evenly(projection.points2D, count: DrawingTemplate.pointCount)
        let distance = Procrustes.bestDistance(drawing: resampled, template: template)
        let shape = min(1, max(0, 1 - (distance - shapePerfectDistance) / shapeRange))

        let extent = Self.extent(projection.points2D)
        let size = min(1, extent / targetExtent)

        let peaks = Smoothness.peaksPerMeter(samples: samples)
        let wobble = Wobble.amplitude(points2D: projection.points2D)
        let smoothness = Wobble.score(amplitude: wobble) * wobbleShare
            + Smoothness.score(peaksPerMeter: peaks) * (1 - wobbleShare)

        let weighted = shape * shapeWeight + size * sizeWeight + smoothness * smoothnessWeight
        let duration = Float((samples.last?.time ?? 0) - (samples.first?.time ?? 0))

        return DrawingScore(
            shape: shape, size: size, smoothness: smoothness,
            total: Int((weighted * 100).rounded()),
            extentMeters: extent, durationSeconds: duration,
            procrustesDistance: distance, peaksPerMeter: peaks, wobbleMeters: wobble,
            motions: Smoothness.movementUnits(strokes: strokes)
        )
    }

    static func extent(_ points: [SIMD2<Float>]) -> Float {
        guard let first = points.first else { return 0 }
        var lo = first
        var hi = first
        for p in points.dropFirst() {
            lo = simd_min(lo, p)
            hi = simd_max(hi, p)
        }
        let size = hi - lo
        return max(size.x, size.y)
    }
}
