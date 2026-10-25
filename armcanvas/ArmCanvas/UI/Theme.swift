import SwiftUI
import UIKit

/// Off-white ground, white cards, orange as the single accent.
enum Theme {
    static let background = Color(red: 0.96, green: 0.95, blue: 0.93)
    static let card = Color.white
    static let accent = Color.orange
    static let accentUI = UIColor.systemOrange
    static let track = Color.black.opacity(0.08)
}

extension View {
    /// White rounded card on the off-white ground.
    func card(padding: CGFloat = 14, cornerRadius: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
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
