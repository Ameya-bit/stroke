import Foundation
import Combine
import ARKit

struct ScoreReport: Equatable {
    let template: DrawingTemplate
    let entry: ScoreEntry
    let rank: Int
    let rankedCount: Int
}

enum SessionState: Equatable {
    case home
    case drawing(DrawingTemplate)
    case scored(ScoreReport)
    case calibrating(secondsLeft: Int)
    case calibrated(ReachEnvelope)
}

enum JudgeStatus: Equatable {
    case idle
    case judging
    case done(JudgeResult)
    case failed(String)
}

/// Drives the exercise flow on top of the drawing primitives.
final class ExerciseController: ObservableObject {
    static let calibrationSeconds: TimeInterval = 15
    private static let playerKey = "playerName"

    let drawing = DrawingSession()
    let leaderboard = LeaderboardStore()
    private let judge = GeminiJudge()

    @Published private(set) var state: SessionState = .home
    @Published private(set) var judgeStatus: JudgeStatus = .idle
    @Published var playerName: String {
        didSet { UserDefaults.standard.set(playerName, forKey: Self.playerKey) }
    }
    private(set) var frame: SessionFrame?

    private var calibrationStart: TimeInterval?
    private var calibrationPoints: [SIMD3<Float>] = []
    private var lastViews: [DrawingSnapshots.View] = []

    var hasJudge: Bool { judge != nil }

    init() {
        playerName = UserDefaults.standard.string(forKey: Self.playerKey) ?? ""
        drawing.frameObserver = { [weak self] arFrame in
            self?.observe(arFrame)
        }
    }

    // MARK: Drawing flow

    func startDrawing(_ template: DrawingTemplate) {
        drawing.clear()
        judgeStatus = .idle
        state = .drawing(template)
    }

    func finishDrawing() {
        guard case .drawing(let template) = state else { return }
        drawing.endDrawing()
        guard let score = DrawingScorer.score(strokes: drawing.strokes, template: template) else { return }

        let entry = ScoreEntry(
            id: UUID(),
            player: playerName.trimmingCharacters(in: .whitespaces).isEmpty ? "Player" : playerName,
            templateID: template.id,
            score: score,
            date: Date()
        )
        leaderboard.add(entry)
        let report = ScoreReport(
            template: template,
            entry: entry,
            rank: leaderboard.rank(of: entry),
            rankedCount: leaderboard.entries(for: template.id).count
        )
        lastViews = DrawingSnapshots.render(strokes: drawing.strokes)
        state = .scored(report)
        requestJudgement(template: template)
    }

    func requestJudgement(template: DrawingTemplate) {
        guard let judge else {
            judgeStatus = .failed(JudgeError.missingKey.localizedDescription)
            return
        }
        guard !lastViews.isEmpty else {
            judgeStatus = .failed("Nothing to judge.")
            return
        }
        judgeStatus = .judging
        let views = lastViews
        Task { @MainActor [weak self] in
            do {
                let result = try await judge.judge(views: views, target: template)
                self?.judgeStatus = .done(result)
            } catch {
                self?.judgeStatus = .failed(error.localizedDescription)
            }
        }
    }

    func goHome() {
        drawing.endDrawing()
        drawing.clear()
        judgeStatus = .idle
        state = .home
    }

    // MARK: Calibration

    func startCalibration() {
        guard drawing.ar.isTrackingNormal else { return }
        frame = SessionFrame(cameraTransform: drawing.ar.cameraTransform)
        calibrationPoints = []
        calibrationStart = nil
        drawing.clear()
        drawing.beginDrawing(color: .systemBlue)
        state = .calibrating(secondsLeft: Int(Self.calibrationSeconds))
    }

    func cancelCalibration() {
        drawing.endDrawing()
        calibrationStart = nil
        goHome()
    }

    private func observe(_ arFrame: ARFrame) {
        guard case .calibrating = state, let frame, drawing.ar.isTrackingNormal else { return }
        let start = calibrationStart ?? arFrame.timestamp
        calibrationStart = start

        let t = arFrame.camera.transform
        let cameraWorld = SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        calibrationPoints.append(frame.toLocal(cameraWorld))

        let elapsed = arFrame.timestamp - start
        let secondsLeft = max(0, Int(ceil(Self.calibrationSeconds - elapsed)))
        if elapsed >= Self.calibrationSeconds {
            finishCalibration()
        } else if state != .calibrating(secondsLeft: secondsLeft) {
            state = .calibrating(secondsLeft: secondsLeft)
        }
    }

    private func finishCalibration() {
        drawing.endDrawing()
        let envelope = ReachEnvelope.from(localPoints: calibrationPoints)
        state = .calibrated(envelope)
    }
}
