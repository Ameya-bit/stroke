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

    private var isRemote: Bool { drawing.viewMode == .remote }
    private var hasGuess: Bool { if case .idle = controller.judgeStatus { return false } else { return true } }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                TrackingBanner(ar: ar)
                Spacer()
                viewToggle
            }
            if isRemote {
                templateCard
                drawPad
            } else {
                Spacer()
            }
            if template.isFree, hasGuess { guessCard }
            bottomButtons
        }
        .padding()
    }

    private var viewToggle: some View {
        Button {
            drawing.toggleViewMode()
        } label: {
            Label(isRemote ? "Camera" : "Remote",
                  systemImage: isRemote ? "camera.fill" : "gamecontroller.fill")
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
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                if let run = controller.session {
                    Text("Drawing \(run.itemIndex + 1) of \(run.plan.items.count) · rep \(run.rep) of \(run.item.reps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(template.name).font(.title3.weight(.semibold))
                Text(template.instruction).font(.subheadline).foregroundStyle(.secondary)
                if !template.isFree {
                    Text("Aim for about \(Int((controller.currentTarget ?? template.targetExtentMeters) * 100)) cm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .card()
    }

    private var drawPad: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(drawing.isDrawing ? Theme.accent : Theme.card)
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
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
                .foregroundStyle(drawing.isDrawing ? Color.white : Color.secondary)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in drawing.beginDrawing() }
                    .onEnded { _ in drawing.endDrawing() }
            )
    }

    @ViewBuilder
    private var guessCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("AI guess", systemImage: "sparkles").font(.headline)
            switch controller.judgeStatus {
            case .idle:
                EmptyView()
            case .judging:
                HStack { ProgressView(); Text("Looking at your drawing…") }
            case .done(let result):
                Text("It looks like \(result.guess.lowercased()).").font(.subheadline.weight(.semibold))
                Text(result.feedback).font(.subheadline)
            case .failed(let message):
                Text("The AI couldn't look at it.").font(.subheadline.weight(.semibold))
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .opacity(isRemote ? 1 : 0.94)
    }

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Button("Home") { controller.goHome() }
                .buttonStyle(.bordered)
                .tint(.primary)
            Button("Clear") { controller.clearDrawing() }
                .buttonStyle(.bordered)
                .tint(.primary)
                .disabled(drawing.strokeCount == 0)
            Button(template.isFree ? "What is it?" : "Done") { controller.finishDrawing() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(drawing.strokeCount == 0)
            Spacer()
            Text("\(drawing.strokeCount) stroke\(drawing.strokeCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(isRemote ? Color.secondary : Color.white)
                .shadow(radius: isRemote ? 0 : 2)
        }
    }
}
