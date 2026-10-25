import SwiftUI

struct RootView: View {
    @StateObject private var controller = ExerciseController()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            SceneLayer(drawing: controller.drawing)
            content
        }
        .preferredColorScheme(.light)
        .onDisappear { controller.drawing.ar.pause() }
    }

    @ViewBuilder
    private var content: some View {
        switch controller.state {
        case .home:
            HomeView(controller: controller)
        case .drawing(let template):
            DrawHUD(controller: controller, template: template)
        case .scored(let report):
            ScoreView(controller: controller, report: report)
        case .sessionSummary(let summary):
            SessionSummaryView(controller: controller, summary: summary)
        case .calibrating(let secondsLeft):
            CalibrationHUD(controller: controller, secondsLeft: secondsLeft)
        case .calibrated(let envelope):
            VStack {
                Spacer()
                EnvelopeCard(envelope: envelope) { controller.goHome() }
            }
            .padding()
        }
    }
}

/// Hosts the AR view. It is hidden by the session manager in remote mode
/// and covered by the ground colour while not drawing.
private struct SceneLayer: View {
    @ObservedObject var drawing: DrawingSession

    var body: some View {
        ZStack {
            ARViewContainer(sceneView: drawing.ar.sceneView)
                .ignoresSafeArea()
            if drawing.viewMode == .remote {
                Theme.background.ignoresSafeArea()
            }
        }
    }
}
