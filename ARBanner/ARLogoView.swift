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

        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

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
        private var planeAnchors: [UUID: ModelEntity] = [:]

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
            DispatchQueue.main.async { [weak self] in
                for anchor in anchors {
                    if let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical {
                        self?.addPlaneVisualization(for: planeAnchor)
                    }
                }
            }
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            DispatchQueue.main.async { [weak self] in
                for anchor in anchors {
                    if let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical {
                        self?.updatePlaneVisualization(for: planeAnchor)
                    }
                }
            }
        }

        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            DispatchQueue.main.async { [weak self] in
                for anchor in anchors {
                    if let planeAnchor = anchor as? ARPlaneAnchor {
                        self?.removePlaneVisualization(for: planeAnchor)
                    }
                }
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

        private func addPlaneVisualization(for planeAnchor: ARPlaneAnchor) {
            guard let arView = arView else { return }

            // Limit plane visualization size for performance
            let maxSize: Float = 2.0
            let width = min(planeAnchor.extent.x, maxSize)
            let height = min(planeAnchor.extent.z, maxSize)

            let mesh = MeshResource.generatePlane(width: width, height: height)
            var material = UnlitMaterial(color: .blue)
            material.color = .init(tint: .blue.withAlphaComponent(0.2))

            let planeEntity = ModelEntity(mesh: mesh, materials: [material])
            planeEntity.transform.translation = [planeAnchor.center.x, 0, planeAnchor.center.z]

            let anchorEntity = AnchorEntity(anchor: planeAnchor)
            anchorEntity.addChild(planeEntity)

            planeAnchors[planeAnchor.identifier] = planeEntity
            arView.scene.addAnchor(anchorEntity)
        }

        private func updatePlaneVisualization(for planeAnchor: ARPlaneAnchor) {
            guard let planeEntity = planeAnchors[planeAnchor.identifier] else { return }

            // Limit plane visualization size for performance
            let maxSize: Float = 2.0
            let width = min(planeAnchor.extent.x, maxSize)
            let height = min(planeAnchor.extent.z, maxSize)

            let mesh = MeshResource.generatePlane(width: width, height: height)
            planeEntity.model?.mesh = mesh
            planeEntity.transform.translation = [planeAnchor.center.x, 0, planeAnchor.center.z]
        }

        private func removePlaneVisualization(for planeAnchor: ARPlaneAnchor) {
            planeAnchors.removeValue(forKey: planeAnchor.identifier)
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            let tapLocation = sender.location(in: arView)
            let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .vertical)

            if let result = results.first {
                placeLogo(at: result.worldTransform)
                // Hide plane visualizations after placing logo
                hidePlaneVisualizations()
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

        private func hidePlaneVisualizations() {
            guard let arView = arView else { return }

            for anchor in arView.scene.anchors {
                if let anchorEntity = anchor as? AnchorEntity,
                   anchorEntity.anchor is ARPlaneAnchor {
                    anchorEntity.isEnabled = false
                }
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
