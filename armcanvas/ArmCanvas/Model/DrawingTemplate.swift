import Foundation
import simd

/// A shape the user draws in the air. Points are in unit-ish 2D coordinates,
/// y up, resampled to `pointCount` evenly spaced samples along the path.
struct DrawingTemplate: Identifiable, Equatable {
    static let pointCount = 64

    let id: String
    let name: String
    let works: String
    let instruction: String
    let targetExtentMeters: Float
    let isClosed: Bool
    let points: [SIMD2<Float>]

    init(id: String, name: String, works: String, instruction: String,
         targetExtentMeters: Float, isClosed: Bool, points: [SIMD2<Float>]) {
        self.id = id
        self.name = name
        self.works = works
        self.instruction = instruction
        self.targetExtentMeters = targetExtentMeters
        self.isClosed = isClosed
        // Space points evenly by arc length so they line up with resampled drawings.
        let closedPath = isClosed ? points + [points[0]] : points
        let even = Resample.evenly(closedPath, count: isClosed ? Self.pointCount + 1 : Self.pointCount)
        self.points = isClosed ? Array(even.dropLast()) : even
    }

    static func == (lhs: DrawingTemplate, rhs: DrawingTemplate) -> Bool { lhs.id == rhs.id }

    static let all: [DrawingTemplate] = [
        DrawingTemplate(
            id: "circle", name: "Big circle",
            works: "Shoulder circumduction",
            instruction: "Draw one circle as large and round as you can.",
            targetExtentMeters: 0.5, isClosed: true,
            points: Shapes.circle()
        ),
        DrawingTemplate(
            id: "figure8", name: "Figure 8",
            works: "Wrist + shoulder coordination",
            instruction: "Draw a wide sideways figure 8, crossing in front of you.",
            targetExtentMeters: 0.6, isClosed: true,
            points: Shapes.figureEight()
        ),
        DrawingTemplate(
            id: "wallclimb", name: "Wall climb",
            works: "Shoulder flexion",
            instruction: "Draw straight up as high as you can, then back down.",
            targetExtentMeters: 0.6, isClosed: false,
            points: Shapes.outAndBack(direction: SIMD2<Float>(0, 1))
        ),
        DrawingTemplate(
            id: "sweep", name: "Side sweep",
            works: "Abduction + adduction",
            instruction: "Sweep your arm out to the side and back across.",
            targetExtentMeters: 0.7, isClosed: false,
            points: Shapes.outAndBack(direction: SIMD2<Float>(1, 0))
        ),
        DrawingTemplate(
            id: "spiral", name: "Spiral",
            works: "Control + progressive range",
            instruction: "Start small in the middle and spiral outward.",
            targetExtentMeters: 0.4, isClosed: false,
            points: Shapes.spiral()
        ),
        DrawingTemplate(
            id: "star", name: "Star",
            works: "Fun level",
            instruction: "Draw a five-point star in one stroke.",
            targetExtentMeters: 0.4, isClosed: true,
            points: Shapes.star()
        ),
    ]

    static func named(_ id: String) -> DrawingTemplate? {
        all.first { $0.id == id }
    }
}

enum Shapes {
    private static let n = DrawingTemplate.pointCount

    static func circle() -> [SIMD2<Float>] {
        (0..<n).map { i in
            let t = Float(i) / Float(n) * 2 * .pi
            return SIMD2<Float>(cos(t), sin(t))
        }
    }

    static func figureEight() -> [SIMD2<Float>] {
        (0..<n).map { i in
            let t = Float(i) / Float(n) * 2 * .pi
            return SIMD2<Float>(cos(t), 0.5 * sin(2 * t))
        }
    }

    static func outAndBack(direction: SIMD2<Float>) -> [SIMD2<Float>] {
        let half = n / 2
        let out = (0..<half).map { i in direction * (-1 + 2 * Float(i) / Float(half - 1)) }
        let back = (0..<half).map { i in direction * (1 - 2 * Float(i) / Float(half - 1)) }
        return out + back
    }

    static func spiral() -> [SIMD2<Float>] {
        (0..<n).map { i in
            let t = Float(i) / Float(n - 1)
            let angle = t * 2 * .pi * 2.5
            let r = 0.1 + 0.9 * t
            return SIMD2<Float>(r * cos(angle), r * sin(angle))
        }
    }

    static func star() -> [SIMD2<Float>] {
        let vertices = (0..<6).map { k -> SIMD2<Float> in
            let angle = Float.pi / 2 + Float(k) * 2 * .pi * 2 / 5
            return SIMD2<Float>(cos(angle), sin(angle))
        }
        return Resample.evenly(vertices, count: n)
    }
}
