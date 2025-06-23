// ARLogoView.swift
// ARBanner
//
// AR view for placing a logo on a detected wall

import SwiftUI
import RealityKit
import ARKit

struct ARLogoView: View {
    var body: some View {
        ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical] // Detect vertical planes (walls)
        arView.session.run(config)

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)

        context.coordinator.arView = arView
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        weak var arView: ARView?

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            let tapLocation = sender.location(in: arView)
            let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .vertical)
            if let result = results.first {
                // Place the logo (ensure a logo image named "logo" is in your asset catalog)
                let anchor = AnchorEntity(world: result.worldTransform)
                let mesh = MeshResource.generatePlane(width: 0.3, height: 0.3)
                let material: RealityKit.Material
                if let image = UIImage(named: "logo"), let cgImage = image.cgImage {
                    do {
                      let texture = try TextureResource.generate(from: cgImage, options: .init(semantic: .color, compression: .none))
                        var unlitMaterial = RealityKit.UnlitMaterial()
                        unlitMaterial.baseColor = .texture(texture)
                        material = unlitMaterial
                    } catch {
                        material = RealityKit.UnlitMaterial(color: .red)
                    }
                } else {
                    material = RealityKit.UnlitMaterial(color: .red)
                }
                let logoPlane = ModelEntity(mesh: mesh, materials: [material])
                // Orient plane to face out from the wall
                logoPlane.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                anchor.addChild(logoPlane)
                arView.scene.addAnchor(anchor)
            }
        }
    }
}

private extension simd_float4x4 {
    var translation: SIMD3<Float> {
        let t = columns.3
        return [t.x, t.y, t.z]
    }
}
