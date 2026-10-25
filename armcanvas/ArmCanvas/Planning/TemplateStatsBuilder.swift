import Foundation

enum TemplateStatsBuilder {
    static let recentAttempts = 3

    /// The star is a fun level, never prescribed.
    static let prescribable = DrawingTemplate.all.filter { $0.id != "star" }

    static func build(history: [ScoreEntry], now: Date = Date()) -> [TemplateStats] {
        prescribable.map { template in
            let attempts = history.filter { $0.templateID == template.id }.sorted { $0.date > $1.date }
            let recent = attempts.prefix(recentAttempts)
            let avg = recent.isEmpty ? nil : Float(recent.map(\.score.total).reduce(0, +)) / Float(recent.count)
            let days = attempts.first.map { Float(now.timeIntervalSince($0.date) / 86_400) }
            let counted = recent.map(\.score.motions).filter { $0 > 0 }
            let motionRatio = counted.isEmpty ? nil
                : Float(counted.reduce(0, +)) / Float(counted.count) / Float(template.expectedMotions)
            return TemplateStats(
                template_id: template.id,
                default_target_m: template.targetExtentMeters,
                recent_avg_score: avg,
                recent_best_extent_m: recent.map(\.score.extentMeters).max(),
                attempts: attempts.count,
                days_since_last: days,
                recent_motion_ratio: motionRatio
            )
        }
    }
}
