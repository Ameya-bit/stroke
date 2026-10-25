import simd

enum Resample {
    /// Resamples a polyline to `count` points evenly spaced by arc length.
    static func evenly<V: SIMD>(_ points: [V], count: Int) -> [V] where V.Scalar == Float {
        guard points.count >= 2, count >= 2 else { return points }
        let lengths = zip(points, points.dropFirst()).map { length($1 - $0) }
        let total = lengths.reduce(0, +)
        guard total > 0 else { return Array(repeating: points[0], count: count) }

        var result: [V] = []
        var segment = 0
        var segmentStart: Float = 0
        for i in 0..<count {
            let target = total * Float(i) / Float(count - 1)
            while segment < lengths.count - 1, segmentStart + lengths[segment] < target {
                segmentStart += lengths[segment]
                segment += 1
            }
            let segLen = lengths[segment]
            let t = segLen > 0 ? min(1, (target - segmentStart) / segLen) : 0
            result.append(points[segment] + (points[segment + 1] - points[segment]) * t)
        }
        return result
    }

    static func pathLength<V: SIMD>(_ points: [V]) -> Float where V.Scalar == Float {
        zip(points, points.dropFirst()).map { length($1 - $0) }.reduce(0, +)
    }

    private static func length<V: SIMD>(_ v: V) -> Float where V.Scalar == Float {
        (v * v).sum().squareRoot()
    }
}
