import SwiftUI

struct HomeView: View {
    @ObservedObject var controller: ExerciseController
    @ObservedObject private var ar: ARSessionManager
    @State private var isShowingLeaderboard = false

    init(controller: ExerciseController) {
        self.controller = controller
        self.ar = controller.drawing.ar
    }

    var body: some View {
        ZStack {
            Color(white: 0.08).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    playerField
                    Text("Pick a drawing")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                    ForEach(DrawingTemplate.all) { template in
                        templateRow(template)
                    }
                    footer
                }
                .padding()
            }
        }
        .sheet(isPresented: $isShowingLeaderboard) {
            LeaderboardView(store: controller.leaderboard)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ArmCanvas")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text("Draw in the air. Rebuild your reach.")
                .foregroundStyle(.white.opacity(0.7))
            TrackingBanner(ar: ar)
                .padding(.top, 6)
        }
    }

    private var playerField: some View {
        HStack {
            Image(systemName: "person.fill")
            TextField("Your name", text: $controller.playerName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
        }
        .padding(12)
        .background(Color.white.opacity(0.1))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func templateRow(_ template: DrawingTemplate) -> some View {
        Button {
            controller.startDrawing(template)
        } label: {
            HStack(spacing: 16) {
                TemplateShape(template: template)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name).font(.title3.weight(.semibold))
                    Text(template.works).font(.subheadline).opacity(0.7)
                }
                Spacer()
                Image(systemName: "chevron.right").opacity(0.5)
            }
            .padding(14)
            .background(Color.white.opacity(0.08))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                isShowingLeaderboard = true
            } label: {
                Label("Leaderboard", systemImage: "trophy.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.white)

            Button {
                controller.startCalibration()
            } label: {
                Label("Reach test", systemImage: "arrow.up.left.and.arrow.down.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            .disabled(!ar.isTrackingNormal)
        }
        .padding(.top, 8)
    }
}

struct TrackingBanner: View {
    @ObservedObject var ar: ARSessionManager

    var body: some View {
        Text(ar.trackingStatus)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(ar.isTrackingNormal ? Color.green.opacity(0.8) : Color.orange.opacity(0.85))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}
