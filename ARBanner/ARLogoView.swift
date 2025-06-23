// ARLogoView.swift
// ARBanner
//
// AR view for placing a logo on a detected wall

import SwiftUI
import RealityKit
import ARKit

struct ARLogoView: View {
    let arStateManager: ARStateManager

    var body: some View {
        ARViewContainer(arStateManager: arStateManager).edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
    let arStateManager: ARStateManager

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Optimize AR configuration for better performance
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical] // Only detect walls, not horizontal planes
        config.environmentTexturing = .none // Disable for better performance
        config.isLightEstimationEnabled = false // Disable for better performance

                // Check if LiDAR is available and configure accordingly
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }

        // Only run if session isn't already running to avoid conflicts
        if arView.session.currentFrame == nil {
            arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        }

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)

        context.coordinator.arView = arView
        context.coordinator.arStateManager = arStateManager
        context.coordinator.setupPlaneVisualization()
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        var arStateManager: ARStateManager?

        deinit {
            // Properly pause the AR session
            arView?.session.pause()
        }

        func setupPlaneVisualization() {
            guard let arView = arView else { return }
            arView.session.delegate = self
        }

        // MARK: - ARSessionDelegate
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            // No longer adding plane visualizations - just detect planes for placement
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            // No longer updating plane visualizations
        }

        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            // No longer removing plane visualizations
        }

        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            DispatchQueue.main.async { [weak self] in
                self?.arStateManager?.updateTrackingState(camera.trackingState)
            }
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            print("AR Session failed: \(error.localizedDescription)")
        }

        func sessionWasInterrupted(_ session: ARSession) {
            print("AR Session was interrupted")
        }

        func sessionInterruptionEnded(_ session: ARSession) {
            print("AR Session interruption ended")
            // Restart the session if needed
            guard let arView = arView else { return }
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = [.vertical]
            config.environmentTexturing = .none
            config.isLightEstimationEnabled = false
            arView.session.run(config, options: [.resetTracking])
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            let tapLocation = sender.location(in: arView)
            let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .vertical)

            if let result = results.first {
                placeLogo(at: result.worldTransform)
            }
        }

        private func placeLogo(at transform: simd_float4x4) {
            guard let arView = arView, let arStateManager = arStateManager else { return }

            let anchor = AnchorEntity(world: transform)
            let mesh = MeshResource.generatePlane(width: 0.3, height: 0.3) // Slightly smaller for better performance

            let material: RealityKit.Material
            // Try different possible asset names
            let possibleNames = ["logo", "gud-prompt-logo-dark (1)", "gud-prompt-logo-dark"]
            var logoImage: UIImage?

            for name in possibleNames {
                if let image = UIImage(named: name) {
                    logoImage = image
                    break
                }
            }

            if let image = logoImage, let cgImage = image.cgImage {
                do {
                    let texture = try TextureResource.generate(from: cgImage, options: .init(semantic: .color))
                    var unlitMaterial = UnlitMaterial()
                    unlitMaterial.color = .init(texture: .init(texture))
                    material = unlitMaterial
                } catch {
                    print("Failed to create texture: \(error)")
                    material = UnlitMaterial(color: .red)
                }
            } else {
                print("Logo image not found. Tried names: \(possibleNames)")
                material = UnlitMaterial(color: .red)
            }

            let logoPlane = ModelEntity(mesh: mesh, materials: [material])

            // Simple rotation for better performance
            logoPlane.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])

            // Simplified animation for better performance
            var startTransform = logoPlane.transform
            startTransform.scale = [0.1, 0.1, 0.1]
            logoPlane.transform = startTransform

            var endTransform = logoPlane.transform
            endTransform.scale = [1.0, 1.0, 1.0]

            let animation = try! AnimationResource.generate(with: FromToByAnimation(
                from: startTransform,
                to: endTransform,
                duration: 0.3
            ))

            logoPlane.playAnimation(animation)

            anchor.addChild(logoPlane)
            arView.scene.addAnchor(anchor)

            // Update state manager
            arStateManager.addLogo(anchor)

            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
}

private extension simd_float4x4 {
    var translation: SIMD3<Float> {
        let t = columns.3
        return [t.x, t.y, t.z]
    }
}
