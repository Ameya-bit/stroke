import Foundation
import Combine
import ARKit

struct ScoreReport: Equatable {
    let template: DrawingTemplate
    let entry: ScoreEntry
    let rank: Int
    let rankedCount: Int
}

struct SessionSummary: Equatable {
    let sessionID: UUID
    let entries: [ScoreEntry]
    let durationSeconds: TimeInterval

    var averageScore: Int {
        guard !entries.isEmpty else { return 0 }
        return entries.map(\.score.total).reduce(0, +) / entries.count
    }
}

enum SessionState: Equatable {
    case home
    case drawing(DrawingTemplate)
    case scored(ScoreReport)
    case sessionSummary(SessionSummary)
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
    private static let envelopeKey = "reachEnvelope"
    private static let onboardedKey = "hasSeenOnboarding"

    let drawing = DrawingSession()
    let leaderboard = LeaderboardStore()
    private let judge = GeminiJudge()
    private let planner: SessionPlanner = LocalPlanner()
    let backend = BackendClient()
    static let sessionLengthOptions = [4, 8, 12]
    @Published var sessionMinutes = 8 {
        didSet { if sessionMinutes != oldValue { refreshPlan() } }
    }

    @Published private(set) var state: SessionState = .home {
        didSet { syncCamera() }
    }
    @Published private(set) var judgeStatus: JudgeStatus = .idle
    @Published private(set) var session: SessionRun?
    @Published private(set) var nextPlan: SessionPlan
    @Published private(set) var envelope: ReachEnvelope?
    @Published var playerName: String {
        didSet { UserDefaults.standard.set(playerName, forKey: Self.playerKey) }
    }
    @Published var isShowingOnboarding: Bool {
        didSet { UserDefaults.standard.set(!isShowingOnboarding, forKey: Self.onboardedKey) }
    }
    private(set) var frame: SessionFrame?

    private var calibrationStart: TimeInterval?
    private var calibrationPoints: [SIMD3<Float>] = []
    private var lastViews: [DrawingSnapshots.View] = []

    var hasJudge: Bool { judge != nil || backend != nil }
    @Published private(set) var isPlanning = false

    init() {
        let defaults = UserDefaults.standard
        playerName = defaults.string(forKey: Self.playerKey) ?? ""
        isShowingOnboarding = !defaults.bool(forKey: Self.onboardedKey)
        let storedEnvelope = defaults.data(forKey: Self.envelopeKey)
            .flatMap { try? JSONDecoder().decode(ReachEnvelope.self, from: $0) }
        envelope = storedEnvelope
        nextPlan = planner.makePlan(history: leaderboard.entries, envelope: storedEnvelope, minutes: 8)
        drawing.frameObserver = { [weak self] arFrame in
            self?.observe(arFrame)
        }
        refreshPlan()
    }

    /// The camera only runs while drawing or calibrating. Everywhere else it
    /// is paused, which is most of the battery and all of the lag.
    private func syncCamera() {
        switch state {
        case .drawing, .calibrating:
            drawing.ensureRunning()
        case .home, .scored, .sessionSummary, .calibrated:
            drawing.ar.pause()
        }
    }

    // MARK: Sessions

    /// Local plan immediately; replaced by the CP-SAT plan if the backend answers.
    func refreshPlan() {
        nextPlan = planner.makePlan(history: leaderboard.entries, envelope: envelope, minutes: sessionMinutes)
        guard let backend else { return }
        let stats = TemplateStatsBuilder.build(history: leaderboard.entries)
        let reachCap = envelope.map { max($0.widthMeters, $0.heightMeters) * LocalPlanner.envelopeFraction }
        isPlanning = true
        Task { @MainActor [weak self] in
            defer { self?.isPlanning = false }
            do {
                let plan = try await backend.plan(stats: stats, timeBudgetSeconds: (self?.sessionMinutes ?? 8) * 60,
                                                  reachCapMeters: (reachCap ?? 0) > 0.2 ? reachCap : nil)
                guard case .home = self?.state ?? .home else { return }
                self?.nextPlan = plan
            } catch {
                print("backend plan failed, keeping on-device plan: \(error)")
            }
        }
    }

    func startSession() {
        let run = SessionRun(plan: nextPlan)
        session = run
        guard let template = run.template else { return }
        startDrawing(template)
    }

    /// After a scored rep: next rep, next drawing, or the session summary.
    func advanceSession() {
        guard let run = session else { return goHome() }
        if let next = run.advanced(), let template = next.template {
            session = next
            startDrawing(template)
        } else {
            let summary = SessionSummary(
                sessionID: run.id,
                entries: leaderboard.entries(inSession: run.id),
                durationSeconds: Date().timeIntervalSince(run.startedAt)
            )
            session = nil
            drawing.clear()
            judgeStatus = .idle
            refreshPlan()
            state = .sessionSummary(summary)
        }
    }

    // MARK: Drawing flow

    func startDrawing(_ template: DrawingTemplate) {
        drawing.clear()
        judgeStatus = .idle
        state = .drawing(template)
    }

    /// Free draw: clear the canvas and the last guess, stay on the draw screen.
    func clearDrawing() {
        drawing.clear()
        judgeStatus = .idle
    }

    var currentTarget: Float? {
        guard case .drawing(let template) = state else { return nil }
        if let run = session, run.item.templateID == template.id { return run.item.targetExtentMeters }
        return LocalPlanner.target(for: template, history: leaderboard.entries, envelope: envelope)
    }

    func finishDrawing() {
        guard case .drawing(let template) = state else { return }
        drawing.endDrawing()
        if template.isFree {
            lastViews = DrawingSnapshots.render(strokes: drawing.strokes)
            requestJudgement(template: template)
            return
        }
        let target = currentTarget ?? template.targetExtentMeters
        guard let score = DrawingScorer.score(strokes: drawing.strokes, template: template, targetExtentMeters: target) else { return }

        let entry = ScoreEntry(
            player: playerName.trimmingCharacters(in: .whitespaces).isEmpty ? "Player" : playerName,
            templateID: template.id,
            score: score,
            date: Date(),
            targetExtentMeters: target,
            sessionID: session?.id,
            rep: session?.rep
        )
        leaderboard.add(entry)
        if let backend {
            Task {
                do { try await backend.submit(entry) } catch { print("score upload failed: \(error)") }
            }
        }
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
        guard judge != nil || backend != nil else {
            judgeStatus = .failed(JudgeError.missingKey.localizedDescription)
            return
        }
        guard !lastViews.isEmpty else {
            judgeStatus = .failed("Nothing to judge.")
            return
        }
        judgeStatus = .judging
        let views = lastViews
        let backend = self.backend
        let judge = self.judge
        Task { @MainActor [weak self] in
            do {
                let result: JudgeResult
                if let backend {
                    do {
                        result = try await backend.judge(views: views, target: template)
                    } catch let backendError {
                        guard let judge else { throw backendError }
                        print("backend judge failed, falling back to direct: \(backendError)")
                        result = try await judge.judge(views: views, target: template)
                    }
                } else if let judge {
                    result = try await judge.judge(views: views, target: template)
                } else {
                    throw JudgeError.missingKey
                }
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
        session = nil
        refreshPlan()
        state = .home
    }

    // MARK: Calibration

    /// Entering the state starts the camera; recording begins on the first tracked frame.
    func startCalibration() {
        frame = nil
        calibrationPoints = []
        calibrationStart = nil
        drawing.clear()
        state = .calibrating(secondsLeft: Int(Self.calibrationSeconds))
    }

    func cancelCalibration() {
        drawing.endDrawing()
        calibrationStart = nil
        goHome()
    }

    private func observe(_ arFrame: ARFrame) {
        guard case .calibrating = state, drawing.ar.isTrackingNormal else { return }
        if frame == nil {
            frame = SessionFrame(cameraTransform: arFrame.camera.transform)
            drawing.beginDrawing(color: .systemBlue)
        }
        guard let frame else { return }
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
        let measured = ReachEnvelope.from(localPoints: calibrationPoints)
        envelope = measured
        if let data = try? JSONEncoder().encode(measured) {
            UserDefaults.standard.set(data, forKey: Self.envelopeKey)
        }
        refreshPlan()
        state = .calibrated(measured)
    }
}
