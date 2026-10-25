import SceneKit
import UIKit

/// Renders a stroke set offscreen from three orthographic viewpoints
/// (front, side, top relative to the drawing's own best-fit plane).
enum DrawingSnapshots {
    static let imageSize = CGSize(width: 512, height: 512)

    struct View {
        let name: String
        let image: UIImage
    }

    static func render(strokes: [Stroke]) -> [View] {
        let positions = strokes.flatMap { $0.samples.map(\.position) }
        guard positions.count >= 2 else { return [] }
        let projection = PlaneProjection(points: positions)
        let extent = max(0.1, DrawingScorer.extent(projection.points2D))

        let scene = SCNScene()
        scene.background.contents = UIColor.white
        let renderer = StrokeRenderer(scene: scene)
        for stroke in strokes {
            for (a, b) in zip(stroke.samples, stroke.samples.dropFirst()) {
                renderer.addSegment(from: a.position, to: b.position, color: .black)
            }
        }

        let views: [(String, SIMD3<Float>, SIMD3<Float>)] = [
            ("front", projection.normal, projection.minor),
            ("side", projection.major, projection.minor),
            ("top", projection.minor, projection.normal),
        ]
        let offscreen = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        offscreen.scene = scene

        return views.map { name, direction, up in
            let camera = SCNCamera()
            camera.usesOrthographicProjection = true
            camera.orthographicScale = Double(extent * 0.65)
            camera.zNear = 0.01
            camera.zFar = 10
            let node = SCNNode()
            node.camera = camera
            node.simdPosition = projection.centroid + direction * 2
            node.simdLook(at: projection.centroid, up: up, localFront: SIMD3<Float>(0, 0, -1))
            scene.rootNode.addChildNode(node)
            offscreen.pointOfView = node
            let image = offscreen.snapshot(atTime: 0, with: imageSize, antialiasingMode: .multisampling4X)
            node.removeFromParentNode()
            return View(name: name, image: image)
        }
    }
}
