import ARKit
import SceneKit

/// Renders LiDAR scene-reconstruction meshes invisibly so real surfaces
/// write depth and hide strokes behind them. ARSCNViewDelegate callbacks run
/// on the SceneKit render thread, which is the documented place to do this.
final class MeshOcclusion: NSObject, ARSCNViewDelegate {
    static var isSupported: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    /// Rebuilding a mesh anchor's geometry is the expensive part; cap it.
    static let minUpdateInterval: TimeInterval = 0.75
    private var lastUpdate: [UUID: TimeInterval] = [:]

    private let material: SCNMaterial = {
        let material = SCNMaterial()
        material.colorBufferWriteMask = []
        material.writesToDepthBuffer = true
        material.isDoubleSided = true
        return material
    }()

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let meshAnchor = anchor as? ARMeshAnchor else { return nil }
        let node = SCNNode(geometry: geometry(from: meshAnchor.geometry))
        node.renderingOrder = -100
        return node
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let meshAnchor = anchor as? ARMeshAnchor else { return }
        let now = CACurrentMediaTime()
        if let last = lastUpdate[anchor.identifier], now - last < Self.minUpdateInterval { return }
        lastUpdate[anchor.identifier] = now
        node.geometry = geometry(from: meshAnchor.geometry)
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        lastUpdate[anchor.identifier] = nil
    }

    private func geometry(from mesh: ARMeshGeometry) -> SCNGeometry {
        let vertices = mesh.vertices
        let vertexSource = SCNGeometrySource(
            buffer: vertices.buffer,
            vertexFormat: vertices.format,
            semantic: .vertex,
            vertexCount: vertices.count,
            dataOffset: vertices.offset,
            dataStride: vertices.stride
        )
        let faces = mesh.faces
        let faceData = Data(bytes: faces.buffer.contents(), count: faces.buffer.length)
        let element = SCNGeometryElement(
            data: faceData,
            primitiveType: .triangles,
            primitiveCount: faces.count,
            bytesPerIndex: faces.bytesPerIndex
        )
        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
        geometry.materials = [material]
        return geometry
    }
}
