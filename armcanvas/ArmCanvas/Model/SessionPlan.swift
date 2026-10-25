import Foundation

/// One prescribed exercise in a session. Same shape the backend planner returns.
struct PlanItem: Codable, Equatable, Identifiable {
    let templateID: String
    let reps: Int
    let targetExtentMeters: Float
    let reason: String

    var id: String { templateID }
    var template: DrawingTemplate? { DrawingTemplate.named(templateID) }
}

struct SessionPlan: Codable, Equatable {
    let items: [PlanItem]
    let estimatedMinutes: Int
    let source: String

    var totalReps: Int { items.reduce(0) { $0 + $1.reps } }
}
