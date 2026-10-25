import SwiftUI

struct OnboardingView: View {
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("How to hold the pencil")
                    .font(.largeTitle.weight(.bold))
                    .padding(.bottom, 6)
                step(1, "Grip the bottom half of the phone", "The top edge is the pencil tip. Keep the rear camera uncovered or tracking drops.")
                step(2, "Keep the back facing the room", "The camera tracks the room to know where the phone is, even while the screen shows no video.")
                step(3, "Hold the pad to draw", "Press and hold the big pad with your thumb while you move your whole arm. Let go to lift the pencil.")
                step(4, "Tap Camera to see it", "Your drawing stays where you made it, in the room.")
                Spacer()
                Button("Got it", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }

    private func step(_ number: Int, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Theme.accent)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(body).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .card()
    }
}
