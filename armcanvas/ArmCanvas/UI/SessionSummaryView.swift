import SwiftUI

struct SessionSummaryView: View {
    @ObservedObject var controller: ExerciseController
    let summary: SessionSummary

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Text("Session complete")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("\(summary.averageScore)")
                            .font(.system(size: 88, weight: .bold, design: .rounded))
                        Text("average over \(summary.entries.count) reps · \(Int(summary.durationSeconds / 60)) min \(Int(summary.durationSeconds) % 60) s")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    perDrawing
                    Button("Done") { controller.goHome() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                }
                .padding()
            }
        }
    }

    private var perDrawing: some View {
        let groups = Dictionary(grouping: summary.entries, by: \.templateID)
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(DrawingTemplate.all.filter { groups[$0.id] != nil }) { template in
                let reps = groups[template.id] ?? []
                HStack(spacing: 12) {
                    TemplateShape(template: template)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name).font(.subheadline.weight(.semibold))
                        Text("best \(reps.map(\.score.total).max() ?? 0) · biggest \(Int((reps.map(\.score.extentMeters).max() ?? 0) * 100)) cm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(reps.map { "\($0.score.total)" }.joined(separator: " · "))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }
}
