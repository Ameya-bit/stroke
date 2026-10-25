import SwiftUI

struct HomeView: View {
    @ObservedObject var controller: ExerciseController
    @State private var isShowingLeaderboard = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    playerField
                    sessionCard
                    ProgressChartView(store: controller.leaderboard)
                    Text("Pick a drawing")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    templateRow(.free)
                    ForEach(DrawingTemplate.all) { template in
                        templateRow(template)
                    }
                    footer
                }
                .padding()
            }
        }
        .sheet(isPresented: $isShowingLeaderboard) {
            LeaderboardView(store: controller.leaderboard, backend: controller.backend)
        }
        .fullScreenCover(isPresented: $controller.isShowingOnboarding) {
            OnboardingView { controller.isShowingOnboarding = false }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("ArmCanvas")
                    .font(.largeTitle.weight(.bold))
                Spacer()
                Button {
                    controller.isShowingOnboarding = true
                } label: {
                    Label("How to hold", systemImage: "hand.raised")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(.primary)
            }
            Text("Draw in the air. Rebuild your reach.")
                .foregroundStyle(.secondary)
        }
    }

    private var playerField: some View {
        HStack {
            Image(systemName: "person.fill").foregroundStyle(.secondary)
            TextField("Your name", text: $controller.playerName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
        }
        .card(padding: 12, cornerRadius: 12)
    }

    private var sessionCard: some View {
        let plan = controller.nextPlan
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Today's session", systemImage: "calendar")
                    .font(.headline)
                Spacer()
                Text("\(plan.estimatedMinutes) min · \(plan.totalReps) reps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Picker("Length", selection: $controller.sessionMinutes) {
                ForEach(ExerciseController.sessionLengthOptions, id: \.self) { minutes in
                    Text("\(minutes) min").tag(minutes)
                }
            }
            .pickerStyle(.segmented)
            ForEach(plan.items) { item in
                if let template = item.template {
                    HStack(spacing: 12) {
                        TemplateShape(template: template)
                            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(template.name)  ×\(item.reps) · \(Int(item.targetExtentMeters * 100)) cm")
                                .font(.subheadline.weight(.semibold))
                            Text(item.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            HStack {
                Text(controller.isPlanning ? "Planning…" : "Planned \(plan.source)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reshuffle") { controller.refreshPlan() }
                    .font(.caption)
            }
            Button {
                controller.startSession()
            } label: {
                Label("Start session", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .card()
    }

    private func templateRow(_ template: DrawingTemplate) -> some View {
        Button {
            controller.startDrawing(template)
        } label: {
            HStack(spacing: 16) {
                TemplateShape(template: template)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name).font(.title3.weight(.semibold))
                    Text(template.works).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .card()
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    isShowingLeaderboard = true
                } label: {
                    Label("Leaderboard", systemImage: "trophy.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.primary)

                Button {
                    controller.startCalibration()
                } label: {
                    Label(controller.envelope == nil ? "Reach test" : "Redo reach test",
                          systemImage: "arrow.up.left.and.arrow.down.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }
            if let envelope = controller.envelope {
                Text("Reach \(Int(envelope.widthMeters * 100)) × \(Int(envelope.heightMeters * 100)) cm · \(String(format: "%.0f", envelope.volumeLiters)) L")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }
}
