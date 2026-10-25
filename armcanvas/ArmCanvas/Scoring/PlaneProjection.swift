import simd

/// Best-fit plane of a 3D point cloud via PCA (power iteration on the
/// covariance matrix). Gives 2D coordinates in that plane plus the axes,
/// which the snapshot renderer reuses as front / side / top directions.
struct PlaneProjection {
    let centroid: SIMD3<Float>
    let major: SIMD3<Float>
    let minor: SIMD3<Float>
    let normal: SIMD3<Float>
    let points2D: [SIMD2<Float>]

    init(points: [SIMD3<Float>]) {
        let count = Float(max(points.count, 1))
        let centroid = points.reduce(SIMD3<Float>(repeating: 0), +) / count
        let centered = points.map { $0 - centroid }

        var cov = simd_float3x3()
        for p in centered {
            cov += simd_float3x3(columns: (p * p.x, p * p.y, p * p.z))
        }
        let major = Self.dominantEigenvector(of: cov, avoiding: [])
        let minor = Self.dominantEigenvector(of: cov, avoiding: [major])
        let normal = simd_normalize(simd_cross(major, minor))

        self.centroid = centroid
        self.major = major
        self.minor = minor
        self.normal = normal
        self.points2D = centered.map { SIMD2<Float>(simd_dot($0, major), simd_dot($0, minor)) }
    }

    private static func dominantEigenvector(of m: simd_float3x3, avoiding: [SIMD3<Float>]) -> SIMD3<Float> {
        var v = SIMD3<Float>(0.577, 0.577, 0.577)
        for _ in 0..<60 {
            var next = m * v
            for a in avoiding { next -= a * simd_dot(next, a) }
            let len = simd_length(next)
            if len < 1e-9 {
                return fallback(avoiding: avoiding)
            }
            v = next / len
        }
        return v
    }

    private static func fallback(avoiding: [SIMD3<Float>]) -> SIMD3<Float> {
        for candidate in [SIMD3<Float>(1, 0, 0), SIMD3<Float>(0, 1, 0), SIMD3<Float>(0, 0, 1)] {
            var c = candidate
            for a in avoiding { c -= a * simd_dot(c, a) }
            if simd_length(c) > 0.5 { return simd_normalize(c) }
        }
        return SIMD3<Float>(0, 0, 1)
    }
}
