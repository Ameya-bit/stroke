import simd

/// Shape comparison invariant to translation, scale and in-plane rotation.
/// Also searches start point (closed shapes), direction and mirroring so
/// the user can draw the template any way round.
enum Procrustes {
    static func normalize(_ points: [SIMD2<Float>]) -> [SIMD2<Float>] {
        let count = Float(max(points.count, 1))
        let centroid = points.reduce(SIMD2<Float>(repeating: 0), +) / count
        let centered = points.map { $0 - centroid }
        let rms = (centered.map { simd_length_squared($0) }.reduce(0, +) / count).squareRoot()
        guard rms > 1e-6 else { return centered }
        return centered.map { $0 / rms }
    }

    /// RMS distance between two normalized, equal-length point sets after
    /// the optimal rotation. 0 is identical; ~1.41 is unrelated.
    static func distance(_ a: [SIMD2<Float>], _ b: [SIMD2<Float>]) -> Float {
        let n = min(a.count, b.count)
        guard n > 0 else { return .infinity }
        var c: Float = 0
        var s: Float = 0
        for i in 0..<n {
            c += a[i].x * b[i].x + a[i].y * b[i].y
            s += a[i].y * b[i].x - a[i].x * b[i].y
        }
        let value = max(0, 2 - 2 * (c * c + s * s).squareRoot() / Float(n))
        return value.squareRoot()
    }

    static func bestDistance(drawing: [SIMD2<Float>], template: DrawingTemplate) -> Float {
        let a = normalize(drawing)
        let base = normalize(template.points)
        var best = Float.infinity
        for mirrored in [false, true] {
            let m = mirrored ? base.map { SIMD2<Float>(-$0.x, $0.y) } : base
            for reversed in [false, true] {
                let r = reversed ? Array(m.reversed()) : m
                let shifts = template.isClosed ? r.count : 1
                for shift in 0..<shifts {
                    let shifted = Array(r[shift...] + r[..<shift])
                    best = min(best, distance(a, shifted))
                }
            }
        }
        return best
    }
}
