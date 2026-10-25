import ARKit
import SceneKit
import Combine

/// Owns the ARSCNView and world-tracking session. Publishes tracking state
/// and hands every frame's camera transform to `onFrame`.
final class ARSessionManager: NSObject, ObservableObject, ARSessionDelegate {
    let sceneView = ARSCNView(frame: .zero)

    @Published private(set) var trackingStatus: String = "Starting camera…"
    @Published private(set) var isTrackingNormal = false

    private(set) var cameraTransform: simd_float4x4 = matrix_identity_float4x4
    var onFrame: ((ARFrame) -> Void)?

    private let meshOcclusion = MeshOcclusion()

    override init() {
        super.init()
        sceneView.scene = SCNScene()
        sceneView.automaticallyUpdatesLighting = true
        sceneView.session.delegate = self
        if MeshOcclusion.isSupported {
            sceneView.delegate = meshOcclusion
        }
    }

    func start() {
        guard ARWorldTrackingConfiguration.isSupported else {
            trackingStatus = "ARKit not supported on this device"
            return
        }
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.environmentTexturing = .none
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }
        if MeshOcclusion.isSupported {
            config.sceneReconstruction = .mesh
        }
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func pause() {
        sceneView.session.pause()
    }

    // MARK: ARSessionDelegate (delivered on the main queue by default)

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        cameraTransform = frame.camera.transform
        onFrame?(frame)
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let (text, normal) = Self.describe(camera.trackingState)
        trackingStatus = text
        isTrackingNormal = normal
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        trackingStatus = "AR error: \(error.localizedDescription)"
        isTrackingNormal = false
    }

    func sessionWasInterrupted(_ session: ARSession) {
        trackingStatus = "Camera interrupted"
        isTrackingNormal = false
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        start()
    }

    private static func describe(_ state: ARCamera.TrackingState) -> (String, Bool) {
        switch state {
        case .normal:
            return ("Tracking normal", true)
        case .notAvailable:
            return ("Tracking unavailable", false)
        case .limited(.initializing):
            return ("Initializing — move the phone slowly", false)
        case .limited(.excessiveMotion):
            return ("Too fast — slow down", false)
        case .limited(.insufficientFeatures):
            return ("Point at a textured surface", false)
        case .limited(.relocalizing):
            return ("Relocalizing…", false)
        case .limited:
            return ("Tracking limited", false)
        }
    }
}
