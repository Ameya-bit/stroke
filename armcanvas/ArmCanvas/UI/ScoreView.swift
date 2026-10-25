import SwiftUI

struct ScoreView: View {
    @ObservedObject var controller: ExerciseController
    @ObservedObject private var store: LeaderboardStore
    let report: ScoreReport

    init(controller: ExerciseController, report: ScoreReport) {
        self.controller = controller
        self.store = controller.leaderboard
        self.report = report
    }

    private var score: DrawingScore { report.entry.score }

    var body: some View {
        ZStack {
            Color(white: 0.08).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    headline
                    metrics
                    coachCard
                    leaderboard
                    buttons
                }
                .padding()
            }
        }
        .foregroundStyle(.white)
    }

    private var headline: some View {
        VStack(spacing: 6) {
            Text(report.template.name)
                .font(.headline)
                .opacity(0.7)
            Text("\(score.total)")
                .font(.system(size: 88, weight: .bold, design: .rounded))
            Text("#\(report.rank) of \(report.rankedCount) on this drawing")
                .font(.title3.weight(.semibold))
                .foregroundStyle(report.rank == 1 ? .yellow : .white)
        }
    }

    private var metrics: some View {
        VStack(spacing: 10) {
            MetricBar(label: "Shape", value: score.shape, detail: String(format: "%.2f", score.procrustesDistance))
            MetricBar(label: "Size", value: score.size, detail: String(format: "%.0f cm", score.extentMeters * 100))
            MetricBar(label: "Smoothness", value: score.smoothness, detail: String(format: "%.1f mm wobble · %.1f pk/m", score.wobbleMeters * 1000, score.peaksPerMeter))
            Text(String(format: "%.1f s", score.durationSeconds))
                .font(.caption)
                .opacity(0.6)
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var coachCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI coach", systemImage: "sparkles")
                .font(.headline)
            switch controller.judgeStatus {
            case .idle:
                Text("Not requested.").opacity(0.6)
            case .judging:
                HStack { ProgressView().tint(.white); Text("Looking at your drawing…") }
            case .done(let result):
                Text("Looks like: \(result.guess)  ·  match \(result.match)/10")
                    .font(.subheadline.weight(.semibold))
                Text(result.feedback)
            case .failed(let message):
                Text(message).font(.footnote).opacity(0.7)
                Button("Retry") { controller.requestJudgement(template: report.template) }
                    .buttonStyle(.bordered)
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var leaderboard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top scores · \(report.template.name)").font(.headline)
            ForEach(Array(store.entries(for: report.template.id).prefix(5).enumerated()), id: \.element.id) { index, entry in
                HStack {
                    Text("#\(index + 1)").monospacedDigit().frame(width: 36, alignment: .leading)
                    Text(entry.player)
                    Spacer()
                    Text("\(entry.score.total)").monospacedDigit()
                }
                .font(entry.id == report.entry.id ? .body.weight(.bold) : .body)
                .foregroundStyle(entry.id == report.entry.id ? .orange : .white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button("Home") { controller.goHome() }
                .buttonStyle(.bordered)
                .tint(.white)
            Button("Draw again") { controller.startDrawing(report.template) }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
    }
}

struct MetricBar: View {
    let label: String
    let value: Float
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(detail).opacity(0.6).monospacedDigit()
            }
            .font(.subheadline)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(Color.orange).frame(width: geo.size.width * CGFloat(max(0, min(1, value))))
                }
            }
            .frame(height: 10)
        }
    }
}
