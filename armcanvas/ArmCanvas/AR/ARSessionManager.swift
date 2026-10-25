import ARKit
import SceneKit
import Combine

enum TrackingMode: Equatable {
    /// Pose only. Used while the camera feed is hidden.
    case light
    /// Pose plus LiDAR mesh and people segmentation for occlusion.
    case full
}

/// Owns the ARSCNView and world-tracking session. Publishes tracking state
/// and hands every frame's camera transform to `onFrame`.
final class ARSessionManager: NSObject, ObservableObject, ARSessionDelegate {
    let sceneView = ARSCNView(frame: .zero)

    @Published private(set) var trackingStatus: String = "Camera off"
    @Published private(set) var isTrackingNormal = false
    @Published private(set) var isRunning = false

    private(set) var cameraTransform: simd_float4x4 = matrix_identity_float4x4
    private(set) var mode: TrackingMode = .light
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

    /// Starts or reconfigures the session. Switching modes keeps tracking;
    /// only a cold start resets it.
    func run(mode: TrackingMode) {
        guard ARWorldTrackingConfiguration.isSupported else {
            trackingStatus = "ARKit not supported on this device"
            return
        }
        let wasRunning = isRunning
        self.mode = mode
        sceneView.session.run(Self.configuration(for: mode), options: wasRunning ? [] : [.resetTracking, .removeExistingAnchors])
        sceneView.isHidden = mode == .light
        if !wasRunning {
            trackingStatus = "Starting camera…"
            isTrackingNormal = false
        }
        isRunning = true
    }

    func pause() {
        guard isRunning else { return }
        sceneView.session.pause()
        isRunning = false
        isTrackingNormal = false
        trackingStatus = "Camera off"
    }

    private static func configuration(for mode: TrackingMode) -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.environmentTexturing = .none
        guard mode == .full else { return config }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }
        if MeshOcclusion.isSupported {
            config.sceneReconstruction = .mesh
        }
        return config
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
        isRunning = false
        run(mode: mode)
    }

    private static func describe(_ state: ARCamera.TrackingState) -> (String, Bool) {
        switch state {
        case .normal:
            return ("Tracking", true)
        case .notAvailable:
            return ("Tracking unavailable", false)
        case .limited(.initializing):
            return ("Initializing — move the phone slowly", false)
        case .limited(.excessiveMotion):
            return ("Too fast — slow down", false)
        case .limited(.insufficientFeatures):
            return ("Point the back at a textured surface", false)
        case .limited(.relocalizing):
            return ("Relocalizing…", false)
        case .limited:
            return ("Tracking limited", false)
        }
    }
}
