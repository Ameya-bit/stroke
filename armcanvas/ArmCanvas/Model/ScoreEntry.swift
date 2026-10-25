import Foundation

struct ScoreEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let player: String
    let templateID: String
    let score: DrawingScore
    let date: Date
}
