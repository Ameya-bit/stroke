import SwiftUI

/// Draws a template's polyline scaled into the given rect.
struct TemplateShape: Shape {
    let template: DrawingTemplate

    func path(in rect: CGRect) -> Path {
        let points = template.points
        guard let first = points.first else { return Path() }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 1
        let minY = ys.min() ?? 0, maxY = ys.max() ?? 1
        let span = max(maxX - minX, maxY - minY, 0.001)
        let scale = min(rect.width, rect.height) * 0.8 / CGFloat(span)
        let offsetX = rect.midX - CGFloat((minX + maxX) / 2) * scale
        let offsetY = rect.midY + CGFloat((minY + maxY) / 2) * scale

        func map(_ p: SIMD2<Float>) -> CGPoint {
            CGPoint(x: offsetX + CGFloat(p.x) * scale, y: offsetY - CGFloat(p.y) * scale)
        }

        var path = Path()
        path.move(to: map(first))
        for p in points.dropFirst() { path.addLine(to: map(p)) }
        if template.isClosed { path.closeSubpath() }
        return path
    }
}
