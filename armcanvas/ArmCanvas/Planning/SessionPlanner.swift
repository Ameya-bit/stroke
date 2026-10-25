import Foundation

protocol SessionPlanner {
    func makePlan(history: [ScoreEntry], envelope: ReachEnvelope?, minutes: Int) -> SessionPlan
}

/// On-device fallback planner. Picks the two weakest drawings plus one for
/// variety, and steps each target up from the player's recent best.
/// The backend CP-SAT planner replaces this with the same output shape.
struct LocalPlanner: SessionPlanner {
    static let itemCount = 3
    static let repsPerItem = 3
    static let secondsPerRep = 20
    static let progressionStep: Float = 1.05
    static let minTargetFraction: Float = 0.6
    static let recentAttempts = 3
    /// A drawing can use this fraction of the measured reach width or height.
    static let envelopeFraction: Float = 0.85

    func makePlan(history: [ScoreEntry], envelope: ReachEnvelope?, minutes: Int) -> SessionPlan {
        let reps = max(1, min(4, minutes * 60 / Self.secondsPerRep / Self.itemCount))
        let templates = DrawingTemplate.all.filter { $0.id != "star" }
        let ranked = templates.sorted { recentAverage($0, history) < recentAverage($1, history) }
        let weakest = Array(ranked.prefix(Self.itemCount - 1))
        let variety = templates.filter { t in !weakest.contains(t) }.randomElement()
        let chosen = weakest + (variety.map { [$0] } ?? [])

        let items = chosen.map { template in
            PlanItem(
                templateID: template.id,
                reps: reps,
                targetExtentMeters: Self.target(for: template, history: history, envelope: envelope),
                reason: reason(for: template, history: history)
            )
        }
        let minutes = max(1, items.reduce(0) { $0 + $1.reps } * Self.secondsPerRep / 60)
        return SessionPlan(items: items, estimatedMinutes: minutes, source: "on-device")
    }

    static func target(for template: DrawingTemplate, history: [ScoreEntry], envelope: ReachEnvelope?) -> Float {
        let recent = history
            .filter { $0.templateID == template.id }
            .sorted { $0.date > $1.date }
            .prefix(recentAttempts)
        let bestRecent = recent.map(\.score.extentMeters).max()
        var target = bestRecent.map { max($0 * progressionStep, template.targetExtentMeters * minTargetFraction) }
            ?? template.targetExtentMeters
        if let envelope, envelope.sampleCount > 0 {
            let reach = max(envelope.widthMeters, envelope.heightMeters) * envelopeFraction
            if reach > 0.2 { target = min(target, reach) }
        }
        return (target * 100).rounded() / 100
    }

    private func recentAverage(_ template: DrawingTemplate, _ history: [ScoreEntry]) -> Float {
        let recent = history
            .filter { $0.templateID == template.id }
            .sorted { $0.date > $1.date }
            .prefix(Self.recentAttempts)
        guard !recent.isEmpty else { return 0 }
        return Float(recent.map(\.score.total).reduce(0, +)) / Float(recent.count)
    }

    private func reason(for template: DrawingTemplate, history: [ScoreEntry]) -> String {
        let attempts = history.filter { $0.templateID == template.id }
        guard let last = attempts.sorted(by: { $0.date > $1.date }).first else {
            return "New drawing — baseline"
        }
        let weakest = [("shape", last.score.shape), ("size", last.score.size), ("smoothness", last.score.smoothness)]
            .min { $0.1 < $1.1 }!
        return "Last \(last.score.total) · work on \(weakest.0)"
    }
}
