import SwiftUI

struct EnvelopeCard: View {
    let envelope: ReachEnvelope
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Reach envelope")
                .font(.headline)
            Grid(horizontalSpacing: 18, verticalSpacing: 6) {
                GridRow { cell("Left", envelope.left); cell("Right", envelope.right) }
                GridRow { cell("Up", envelope.up); cell("Down", envelope.down) }
                GridRow { cell("Forward", envelope.forward); cell("Volume", envelope.volumeLiters, unit: "L") }
            }
            Text("\(envelope.sampleCount) samples")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func cell(_ label: String, _ meters: Float, unit: String = "cm") -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(unit == "cm" ? String(format: "%.0f cm", meters * 100) : String(format: "%.1f %@", meters, unit))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .frame(minWidth: 90)
    }
}
