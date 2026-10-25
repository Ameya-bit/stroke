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
            Theme.background.ignoresSafeArea()
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
    }

    private var headline: some View {
        VStack(spacing: 6) {
            Text(report.template.name)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("\(score.total)")
                .font(.system(size: 88, weight: .bold, design: .rounded))
            Text("#\(report.rank) of \(report.rankedCount) on this drawing")
                .font(.title3.weight(.semibold))
                .foregroundStyle(report.rank == 1 ? Theme.accent : .primary)
        }
    }

    private var metrics: some View {
        let expected = report.template.expectedMotions
        return VStack(spacing: 10) {
            MetricBar(label: "Shape", value: score.shape, detail: String(format: "%.2f", score.procrustesDistance))
            MetricBar(label: "Size", value: score.size, detail: String(format: "%.0f / %.0f cm", score.extentMeters * 100, report.entry.targetExtentMeters * 100))
            MetricBar(label: "Smoothness", value: score.smoothness, detail: String(format: "%.1f mm wobble · %.1f pk/m", score.wobbleMeters * 1000, score.peaksPerMeter))
            HStack {
                Text("Motions")
                Spacer()
                Text("\(score.motions) · \(expected) expected")
                    .monospacedDigit()
                    .foregroundStyle(score.motions > 2 * expected ? Theme.accent : .secondary)
            }
            .font(.subheadline)
            Text(String(format: "%.1f s", score.durationSeconds))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card(padding: 16)
    }

    @ViewBuilder
    private var coachCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI coach", systemImage: "sparkles")
                .font(.headline)
            switch controller.judgeStatus {
            case .idle:
                Text("Not requested.").foregroundStyle(.secondary)
            case .judging:
                HStack { ProgressView(); Text("Looking at your drawing…") }
            case .done(let result):
                Text("Looks like: \(result.guess)  ·  match \(result.match)/10")
                    .font(.subheadline.weight(.semibold))
                Text(result.feedback)
            case .failed(let message):
                Text(message).font(.footnote).foregroundStyle(.secondary)
                Button("Retry") { controller.requestJudgement(template: report.template) }
                    .buttonStyle(.bordered)
                    .tint(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
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
                .foregroundStyle(entry.id == report.entry.id ? Theme.accent : .primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }

    @ViewBuilder
    private var buttons: some View {
        if let run = controller.session {
            HStack(spacing: 12) {
                Button("End session") { controller.goHome() }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                Button(run.advanced() == nil ? "Finish session" : "Next rep") { controller.advanceSession() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
        } else {
            HStack(spacing: 12) {
                Button("Home") { controller.goHome() }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                Button("Draw again") { controller.startDrawing(report.template) }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
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
                Text(detail).foregroundStyle(.secondary).monospacedDigit()
            }
            .font(.subheadline)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule().fill(Theme.accent).frame(width: geo.size.width * CGFloat(max(0, min(1, value))))
                }
            }
            .frame(height: 10)
        }
    }
}
