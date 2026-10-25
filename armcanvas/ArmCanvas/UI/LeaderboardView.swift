import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var store: LeaderboardStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(DrawingTemplate.all) { template in
                    let entries = store.entries(for: template.id)
                    if !entries.isEmpty {
                        Section(template.name) {
                            ForEach(Array(entries.prefix(10).enumerated()), id: \.element.id) { index, entry in
                                HStack {
                                    Text("#\(index + 1)").monospacedDigit().frame(width: 36, alignment: .leading)
                                    Text(entry.player)
                                    Spacer()
                                    Text("\(entry.score.total)").monospacedDigit().bold()
                                }
                            }
                        }
                    }
                }
                if store.entries.isEmpty {
                    Text("No scores yet. Draw something!")
                }
            }
            .navigationTitle("Leaderboard")
        }
    }
}
