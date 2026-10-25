import Foundation

/// JSON-backed list of every scored drawing on this phone.
final class LeaderboardStore: ObservableObject {
    @Published private(set) var entries: [ScoreEntry] = []
    private let url: URL

    init(filename: String = "leaderboard.json") {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = documents.appendingPathComponent(filename)
        entries = Self.load(from: url)
    }

    func add(_ entry: ScoreEntry) {
        entries = entries + [entry]
        save()
    }

    func entries(for templateID: String) -> [ScoreEntry] {
        entries.filter { $0.templateID == templateID }.sorted { $0.score.total > $1.score.total }
    }

    func entries(inSession sessionID: UUID) -> [ScoreEntry] {
        entries.filter { $0.sessionID == sessionID }.sorted { $0.date < $1.date }
    }

    /// Oldest-first attempts of one template, for progress charts.
    func history(for templateID: String) -> [ScoreEntry] {
        entries.filter { $0.templateID == templateID }.sorted { $0.date < $1.date }
    }

    /// 1-based rank of `entry` among all entries for its template.
    func rank(of entry: ScoreEntry) -> Int {
        let ranked = entries(for: entry.templateID)
        return (ranked.firstIndex { $0.id == entry.id } ?? ranked.count) + 1
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Leaderboard save failed: \(error)")
        }
    }

    private static func load(from url: URL) -> [ScoreEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        do {
            return try JSONDecoder().decode([ScoreEntry].self, from: data)
        } catch {
            print("Leaderboard load failed: \(error)")
            return []
        }
    }
}
