import SwiftUI

struct DrawHUD: View {
    @ObservedObject var controller: ExerciseController
    @ObservedObject private var drawing: DrawingSession
    @ObservedObject private var ar: ARSessionManager
    let template: DrawingTemplate

    init(controller: ExerciseController, template: DrawingTemplate) {
        self.controller = controller
        self.drawing = controller.drawing
        self.ar = controller.drawing.ar
        self.template = template
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                TrackingBanner(ar: ar)
                Spacer()
                viewToggle
            }
            if drawing.viewMode == .remote {
                templateCard
                drawPad
            } else {
                Spacer()
            }
            bottomButtons
        }
        .padding()
    }

    private var viewToggle: some View {
        Button {
            drawing.toggleViewMode()
        } label: {
            Label(drawing.viewMode == .camera ? "Remote" : "Camera",
                  systemImage: drawing.viewMode == .camera ? "gamecontroller.fill" : "camera.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(Color.black.opacity(0.55))
        .foregroundStyle(.white)
        .clipShape(Capsule())
    }

    private var templateCard: some View {
        HStack(spacing: 14) {
            TemplateShape(template: template)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name).font(.title3.weight(.semibold))
                Text(template.instruction).font(.subheadline).opacity(0.75)
                Text("Aim for about \(Int(template.targetExtentMeters * 100)) cm")
                    .font(.caption).opacity(0.6)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var drawPad: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(drawing.isDrawing ? Color.orange : Color.white.opacity(0.12))
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 44))
                    Text(drawing.isDrawing ? "Drawing…" : "Hold to draw")
                        .font(.title2.weight(.semibold))
                    Text("Top edge of the phone is the pencil tip")
                        .font(.footnote)
                        .opacity(0.7)
                }
                .foregroundStyle(.white)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in drawing.beginDrawing() }
                    .onEnded { _ in drawing.endDrawing() }
            )
    }

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Button("Home") { controller.goHome() }
                .buttonStyle(.bordered)
                .tint(.white)
            Button("Clear") { drawing.clear() }
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(drawing.strokeCount == 0)
            Button("Done") { controller.finishDrawing() }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(drawing.strokeCount == 0)
            Spacer()
            Text("\(drawing.strokeCount) stroke\(drawing.strokeCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.white)
                .shadow(radius: 2)
        }
    }
}
