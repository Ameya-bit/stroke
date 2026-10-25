import simd

/// Body-relative coordinate frame fixed when the user taps Start while holding
/// the phone at chest height. Local axes: +x right, +y up, +z forward.
struct SessionFrame: Codable {
    let origin: SIMD3<Float>
    let forward: SIMD3<Float>
    let right: SIMD3<Float>
    static let up = SIMD3<Float>(0, 1, 0)

    init(cameraTransform t: simd_float4x4) {
        origin = SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        let cameraForward = -SIMD3<Float>(t.columns.2.x, t.columns.2.y, t.columns.2.z)
        let flat = SIMD3<Float>(cameraForward.x, 0, cameraForward.z)
        forward = simd_length(flat) > 0.001 ? simd_normalize(flat) : SIMD3<Float>(0, 0, -1)
        right = simd_normalize(simd_cross(forward, Self.up))
    }

    func toLocal(_ world: SIMD3<Float>) -> SIMD3<Float> {
        let d = world - origin
        return SIMD3<Float>(simd_dot(d, right), simd_dot(d, Self.up), simd_dot(d, forward))
    }

    func toWorld(_ local: SIMD3<Float>) -> SIMD3<Float> {
        origin + right * local.x + Self.up * local.y + forward * local.z
    }
}
