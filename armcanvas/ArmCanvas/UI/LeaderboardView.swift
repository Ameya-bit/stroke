import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var store: LeaderboardStore
    let backend: BackendClient?

    @State private var scope = Scope.phone
    @State private var remote: [String: [RemoteScore]] = [:]
    @State private var remoteError: String?
    @State private var isLoading = false

    enum Scope: String, CaseIterable { case phone = "This phone", everyone = "Everyone" }

    var body: some View {
        NavigationStack {
            List {
                if backend != nil {
                    Picker("Scope", selection: $scope) {
                        ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }
                if scope == .phone { localSections } else { remoteSections }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Leaderboard")
        }
        .task(id: scope) { if scope == .everyone { await loadRemote() } }
    }

    @ViewBuilder
    private var localSections: some View {
        ForEach(DrawingTemplate.all) { template in
            let entries = store.entries(for: template.id)
            if !entries.isEmpty {
                section(template.name, rows: entries.prefix(10).map { ($0.id.uuidString, $0.player, $0.score.total) })
            }
        }
        if store.entries.isEmpty {
            Text("No scores yet. Draw something!")
        }
    }

    @ViewBuilder
    private var remoteSections: some View {
        if isLoading { HStack { ProgressView(); Text("Loading…") } }
        if let remoteError { Text(remoteError).foregroundStyle(.secondary) }
        ForEach(DrawingTemplate.all) { template in
            if let entries = remote[template.id], !entries.isEmpty {
                section(template.name, rows: entries.map { ($0.id, $0.player, $0.total) })
            }
        }
        if !isLoading, remoteError == nil, remote.values.allSatisfy(\.isEmpty) {
            Text("Nobody has scored yet.")
        }
    }

    private func section(_ title: String, rows: [(String, String, Int)]) -> some View {
        Section(title) {
            ForEach(Array(rows.enumerated()), id: \.element.0) { index, row in
                HStack {
                    Text("#\(index + 1)").monospacedDigit().frame(width: 36, alignment: .leading)
                    Text(row.1)
                    Spacer()
                    Text("\(row.2)").monospacedDigit().bold()
                }
            }
        }
    }

    private func loadRemote() async {
        guard let backend else { return }
        isLoading = true
        remoteError = nil
        defer { isLoading = false }
        var result: [String: [RemoteScore]] = [:]
        for template in DrawingTemplate.all {
            do {
                result[template.id] = try await backend.topScores(templateID: template.id)
            } catch {
                remoteError = "Couldn't reach the server: \(error.localizedDescription)"
                return
            }
        }
        remote = result
    }
}
