import SwiftUI

struct CalibrationHUD: View {
    @ObservedObject var controller: ExerciseController
    let secondsLeft: Int

    var body: some View {
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
                .tint(.white)
            Spacer()
        }
        .foregroundStyle(.white)
        .shadow(radius: 3)
        .padding()
    }
}
