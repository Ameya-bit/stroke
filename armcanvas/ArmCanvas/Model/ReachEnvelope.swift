import simd

/// How far the hand travelled from the session origin in each direction.
/// All extents are positive magnitudes in meters.
struct ReachEnvelope: Codable, Equatable {
    let left: Float
    let right: Float
    let up: Float
    let down: Float
    let forward: Float
    let volumeLiters: Float
    let sampleCount: Int

    static let empty = ReachEnvelope(left: 0, right: 0, up: 0, down: 0, forward: 0, volumeLiters: 0, sampleCount: 0)

    /// `localPoints` are camera positions expressed in a `SessionFrame`.
    static func from(localPoints: [SIMD3<Float>]) -> ReachEnvelope {
        guard let first = localPoints.first else { return .empty }
        var minimum = first
        var maximum = first
        for p in localPoints.dropFirst() {
            minimum = simd_min(minimum, p)
            maximum = simd_max(maximum, p)
        }
        let size = maximum - minimum
        let cubicMeters = size.x * size.y * size.z
        return ReachEnvelope(
            left: max(0, -minimum.x),
            right: max(0, maximum.x),
            up: max(0, maximum.y),
            down: max(0, -minimum.y),
            forward: max(0, maximum.z),
            volumeLiters: cubicMeters * 1000,
            sampleCount: localPoints.count
        )
    }

    var widthMeters: Float { left + right }
    var heightMeters: Float { up + down }
}
