import SceneKit
import simd

/// Draws strokes as chains of thin cylinders in the AR scene.
final class StrokeRenderer {
    private let root = SCNNode()
    private let radius: CGFloat = 0.004
    private var materials: [UIColor: SCNMaterial] = [:]

    init(scene: SCNScene) {
        scene.rootNode.addChildNode(root)
    }

    func addSegment(from a: SIMD3<Float>, to b: SIMD3<Float>, color: UIColor) {
        let delta = b - a
        let length = simd_length(delta)
        guard length > 0.0005, length.isFinite else { return }
        let material = self.material(for: color)

        let cylinder = SCNCylinder(radius: radius, height: CGFloat(length))
        cylinder.materials = [material]
        let segment = SCNNode(geometry: cylinder)
        segment.simdPosition = (a + b) * 0.5
        segment.simdOrientation = Self.orientation(alongUnit: delta / length)
        root.addChildNode(segment)

        let sphere = SCNSphere(radius: radius)
        sphere.materials = [material]
        let joint = SCNNode(geometry: sphere)
        joint.simdPosition = b
        root.addChildNode(joint)
    }

    func clear() {
        root.childNodes.forEach { $0.removeFromParentNode() }
    }

    /// Rotates the cylinder's +Y axis onto `direction`, handling the
    /// antiparallel case that `simd_quatf(from:to:)` leaves undefined.
    private static func orientation(alongUnit direction: SIMD3<Float>) -> simd_quatf {
        let yAxis = SIMD3<Float>(0, 1, 0)
        if simd_dot(yAxis, direction) < -0.9999 {
            return simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
        }
        return simd_quatf(from: yAxis, to: direction)
    }

    private func material(for color: UIColor) -> SCNMaterial {
        if let existing = materials[color] { return existing }
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .constant
        materials[color] = material
        return material
    }
}
