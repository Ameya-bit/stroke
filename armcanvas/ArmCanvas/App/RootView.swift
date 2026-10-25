import SwiftUI

struct RootView: View {
    @StateObject private var controller = ExerciseController()

    var body: some View {
        ZStack {
            SceneLayer(drawing: controller.drawing)
            content
        }
        .onAppear { controller.drawing.ar.start() }
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

/// Keeps the AR view alive (tracking needs the camera) and covers it with
/// a dark remote-control surface while in `.remote` mode.
private struct SceneLayer: View {
    @ObservedObject var drawing: DrawingSession

    var body: some View {
        ZStack {
            ARViewContainer(sceneView: drawing.ar.sceneView)
                .ignoresSafeArea()
            if drawing.viewMode == .remote {
                Color(white: 0.08)
                    .ignoresSafeArea()
            }
        }
    }
}
