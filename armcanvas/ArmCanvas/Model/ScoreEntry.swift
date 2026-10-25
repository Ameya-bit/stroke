import Foundation

struct ScoreEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let player: String
    let templateID: String
    let score: DrawingScore
    let date: Date
    let targetExtentMeters: Float
    let sessionID: UUID?
    let rep: Int?

    init(id: UUID = UUID(), player: String, templateID: String, score: DrawingScore, date: Date,
         targetExtentMeters: Float, sessionID: UUID? = nil, rep: Int? = nil) {
        self.id = id
        self.player = player
        self.templateID = templateID
        self.score = score
        self.date = date
        self.targetExtentMeters = targetExtentMeters
        self.sessionID = sessionID
        self.rep = rep
    }

    // Tolerates entries saved before the session fields existed.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        player = try c.decode(String.self, forKey: .player)
        templateID = try c.decode(String.self, forKey: .templateID)
        score = try c.decode(DrawingScore.self, forKey: .score)
        date = try c.decode(Date.self, forKey: .date)
        targetExtentMeters = try c.decodeIfPresent(Float.self, forKey: .targetExtentMeters)
            ?? DrawingTemplate.named(templateID)?.targetExtentMeters ?? 0.5
        sessionID = try c.decodeIfPresent(UUID.self, forKey: .sessionID)
        rep = try c.decodeIfPresent(Int.self, forKey: .rep)
    }
}
