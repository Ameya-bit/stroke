import simd

/// The pencil tip sits just past the top edge of the phone. In portrait the
/// ARKit camera's local +X axis runs along the phone's long side toward the
/// top edge; the lens itself is ~2cm below that edge.
enum BrushTip {
    static let tipOffsetMeters: Float = 0.04

    static func position(cameraTransform t: simd_float4x4) -> SIMD3<Float> {
        let origin = SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        let towardTopEdge = SIMD3<Float>(t.columns.0.x, t.columns.0.y, t.columns.0.z)
        return origin + simd_normalize(towardTopEdge) * tipOffsetMeters
    }
}
