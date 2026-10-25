import SwiftUI
import Charts

/// Score trend per drawing across all attempts on this phone.
struct ProgressChartView: View {
    @ObservedObject var store: LeaderboardStore
    @State private var selectedID: String = DrawingTemplate.all[0].id

    private var history: [ScoreEntry] { store.history(for: selectedID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                Spacer()
                Picker("Drawing", selection: $selectedID) {
                    ForEach(DrawingTemplate.all) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.menu)
            }

            if history.count < 2 {
                Text("Draw this at least twice to see a trend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 60)
            } else {
                Chart(Array(history.enumerated()), id: \.element.id) { index, entry in
                    LineMark(x: .value("Attempt", index + 1), y: .value("Score", entry.score.total))
                        .foregroundStyle(Theme.accent)
                    PointMark(x: .value("Attempt", index + 1), y: .value("Score", entry.score.total))
                        .foregroundStyle(Theme.accent)
                    LineMark(x: .value("Attempt", index + 1), y: .value("Size cm", Int(entry.score.extentMeters * 100)))
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                }
                .chartYScale(domain: 0...max(100, Int((history.map(\.score.extentMeters).max() ?? 1) * 100) + 5))
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: min(history.count, 6))) }
                .frame(height: 140)
                HStack(spacing: 14) {
                    legend(Theme.accent, "Score")
                    legend(.blue, "Size (cm)")
                    Spacer()
                    Text(trendText).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }

    private var trendText: String {
        guard let first = history.first, let last = history.last else { return "" }
        let delta = last.score.total - first.score.total
        return delta >= 0 ? "+\(delta) since first" : "\(delta) since first"
    }

    private func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
