import Foundation
import Combine
import ARKit

enum ViewMode: Equatable {
    /// Dark controller screen; nothing is rendered while drawing.
    case remote
    /// Live camera feed with strokes placed in the room.
    case camera
}

/// Wires the AR session, the stroke recorder and the renderer together.
final class DrawingSession: ObservableObject {
    static let defaultColor = Theme.accentUI

    let ar = ARSessionManager()
    private let recorder = StrokeRecorder()
    private let renderer: StrokeRenderer
    private let tipMarker: TipMarker
    private var activeColor = DrawingSession.defaultColor
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    @Published private(set) var isDrawing = false
    @Published private(set) var strokeCount = 0
    @Published private(set) var viewMode: ViewMode = .remote

    /// Called with every AR frame after the drawing logic has run.
    var frameObserver: ((ARFrame) -> Void)?

    var strokes: [Stroke] { recorder.strokes }

    init() {
        renderer = StrokeRenderer(scene: ar.sceneView.scene)
        tipMarker = TipMarker(scene: ar.sceneView.scene)
        recorder.onSegment = { [weak self] a, b in
            guard let self else { return }
            self.renderer.addSegment(from: a, to: b, color: self.activeColor)
        }
        ar.onFrame = { [weak self] frame in
            self?.handle(frame)
        }
    }

    func toggleViewMode() {
        setViewMode(viewMode == .camera ? .remote : .camera)
    }

    func setViewMode(_ mode: ViewMode) {
        viewMode = mode
        if ar.isRunning { ar.run(mode: mode == .camera ? .full : .light) }
    }

    /// Starts tracking in the mode matching the current view, if not running.
    func ensureRunning() {
        guard !ar.isRunning else { return }
        ar.run(mode: viewMode == .camera ? .full : .light)
    }

    // MARK: Drawing

    func beginDrawing(color: UIColor = DrawingSession.defaultColor) {
        guard ar.isTrackingNormal, !recorder.isDrawing else { return }
        activeColor = color
        recorder.begin()
        renderer.beginStroke()
        isDrawing = true
        haptic.impactOccurred()
    }

    func endDrawing() {
        guard recorder.isDrawing else { return }
        recorder.end()
        renderer.endStroke()
        isDrawing = false
        strokeCount = recorder.strokeCount
        haptic.impactOccurred(intensity: 0.6)
    }

    func clear() {
        recorder.clear()
        renderer.clear()
        strokeCount = 0
    }

    private func handle(_ frame: ARFrame) {
        defer { frameObserver?(frame) }
        let tip = BrushTip.position(cameraTransform: frame.camera.transform)
        tipMarker.update(position: tip)
        tipMarker.isHidden = !ar.isTrackingNormal

        guard recorder.isDrawing else { return }
        if !ar.isTrackingNormal {
            endDrawing()
            return
        }
        recorder.add(position: tip, time: frame.timestamp)
    }
}
