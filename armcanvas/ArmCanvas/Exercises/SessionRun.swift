import Foundation

/// Progress through a session plan: which item and which rep is next.
struct SessionRun: Equatable {
    let id: UUID
    let plan: SessionPlan
    let itemIndex: Int
    let rep: Int
    let startedAt: Date

    init(plan: SessionPlan) {
        id = UUID()
        self.plan = plan
        itemIndex = 0
        rep = 1
        startedAt = Date()
    }

    private init(id: UUID, plan: SessionPlan, itemIndex: Int, rep: Int, startedAt: Date) {
        self.id = id
        self.plan = plan
        self.itemIndex = itemIndex
        self.rep = rep
        self.startedAt = startedAt
    }

    var item: PlanItem { plan.items[itemIndex] }
    var template: DrawingTemplate? { item.template }
    var completedReps: Int { plan.items.prefix(itemIndex).reduce(0) { $0 + $1.reps } + rep - 1 }

    /// Next rep or item, or nil when the plan is finished.
    func advanced() -> SessionRun? {
        if rep < item.reps {
            return SessionRun(id: id, plan: plan, itemIndex: itemIndex, rep: rep + 1, startedAt: startedAt)
        }
        guard itemIndex + 1 < plan.items.count else { return nil }
        return SessionRun(id: id, plan: plan, itemIndex: itemIndex + 1, rep: 1, startedAt: startedAt)
    }
}
