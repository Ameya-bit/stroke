import SwiftUI

struct CalibrationHUD: View {
    @ObservedObject var controller: ExerciseController
    let secondsLeft: Int

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 12) {
                TrackingBanner(ar: controller.drawing.ar)
                Spacer()
                Text("Reach as far as you can in every direction")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("\(secondsLeft)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Button("Cancel") { controller.cancelCalibration() }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                Spacer()
            }
            .padding()
        }
    }
}
