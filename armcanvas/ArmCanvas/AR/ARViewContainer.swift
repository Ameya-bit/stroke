import SwiftUI
import ARKit

struct ARViewContainer: UIViewRepresentable {
    let sceneView: ARSCNView

    func makeUIView(context: Context) -> ARSCNView {
        sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}
