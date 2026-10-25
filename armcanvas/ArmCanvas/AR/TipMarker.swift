import SceneKit
import simd

/// Small sphere that follows the pencil tip in the AR view.
final class TipMarker {
    private let node: SCNNode

    init(scene: SCNScene) {
        let sphere = SCNSphere(radius: 0.006)
        let material = SCNMaterial()
        material.diffuse.contents = Theme.accentUI
        material.lightingModel = .constant
        sphere.materials = [material]
        node = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(node)
    }

    func update(position: SIMD3<Float>) {
        node.simdPosition = position
    }

    var isHidden: Bool {
        get { node.isHidden }
        set { node.isHidden = newValue }
    }
}
