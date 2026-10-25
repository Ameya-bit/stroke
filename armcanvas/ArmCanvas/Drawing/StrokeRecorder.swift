import Foundation
import simd

/// Records every brush-tip sample at frame rate (timing matters for
/// smoothness scoring) and emits render segments only every `minSpacing`.
final class StrokeRecorder {
    static let minSpacing: Float = 0.01

    private(set) var strokes: [Stroke] = []
    private(set) var current: Stroke?
    private var lastRendered: SIMD3<Float>?
    var onSegment: ((SIMD3<Float>, SIMD3<Float>) -> Void)?

    var isDrawing: Bool { current != nil }
    var strokeCount: Int { strokes.count + (current == nil ? 0 : 1) }

    func begin() {
        current = Stroke()
        lastRendered = nil
    }

    func add(position: SIMD3<Float>, time: TimeInterval) {
        guard let stroke = current else { return }
        current = stroke.appending(Sample(position: position, time: time))

        guard let previous = lastRendered else {
            lastRendered = position
            return
        }
        if simd_distance(previous, position) >= Self.minSpacing {
            onSegment?(previous, position)
            lastRendered = position
        }
    }

    func end() {
        guard let stroke = current else { return }
        if stroke.samples.count > 1 {
            strokes = strokes + [stroke]
        }
        current = nil
        lastRendered = nil
    }

    func clear() {
        strokes = []
        current = nil
        lastRendered = nil
    }
}
