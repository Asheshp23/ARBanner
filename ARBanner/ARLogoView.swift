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

        // Simplified AR configuration to reduce warnings
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical] // Only detect walls, not horizontal planes
        config.environmentTexturing = .none // Disable for better performance
        config.isLightEstimationEnabled = false // Disable for better performance

        // Disable scene reconstruction to reduce warnings
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            // Don't enable scene reconstruction to reduce warnings
        }

        // Only run if session isn't already running to avoid conflicts
        if arView.session.currentFrame == nil {
            arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        }

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)

        // Add pinch gesture for resizing
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        arView.addGestureRecognizer(pinchGesture)

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
        var currentLogoEntity: ModelEntity?
        var currentLogoAnchor: AnchorEntity?

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

        @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
            guard let logoEntity = currentLogoEntity else { return }

            if sender.state == .changed {
                let scale = Float(sender.scale)
                // Limit scale between 0.5x and 3x
                let clampedScale = max(0.5, min(3.0, scale))
                logoEntity.transform.scale = [clampedScale, clampedScale, clampedScale]
            }

            if sender.state == .ended {
                sender.scale = 1.0
            }
        }

        private func placeLogo(at transform: simd_float4x4) {
            guard let arView = arView, let arStateManager = arStateManager else { return }

            // Remove previous logo if exists
            if let previousAnchor = currentLogoAnchor {
                arView.scene.removeAnchor(previousAnchor)
            }

                        let anchor = AnchorEntity(world: transform)

            // Load logo image from Assets and calculate proper dimensions
            let material: RealityKit.Material
            var logoWidth: Float = 0.8
            var logoHeight: Float = 0.8

            if let logoImage = UIImage(named: "logo") {
                print("✅ Logo image loaded successfully: \(logoImage.size)")

                // Calculate aspect ratio and set proper dimensions
                let imageSize = logoImage.size
                let aspectRatio = Float(imageSize.width / imageSize.height)

                // Set a reasonable base size (0.6m) and scale accordingly
                let baseSize: Float = 0.6
                if aspectRatio > 1.0 {
                    // Landscape: width is larger
                    logoWidth = baseSize * aspectRatio
                    logoHeight = baseSize
                } else {
                    // Portrait or square: height is larger or equal
                    logoWidth = baseSize
                    logoHeight = baseSize / aspectRatio
                }

                print("✅ Logo dimensions: \(logoWidth)m x \(logoHeight)m (aspect ratio: \(aspectRatio))")

                do {
                    let texture = try TextureResource.generate(from: logoImage.cgImage!, options: .init(semantic: .color))
                    var unlitMaterial = UnlitMaterial()
                    unlitMaterial.color = .init(texture: .init(texture))
                    // Ensure the material is opaque and visible
                    unlitMaterial.blending = .transparent(opacity: 1.0)
                    material = unlitMaterial
                    print("✅ Texture created successfully")
                } catch {
                    print("❌ Failed to create texture: \(error)")
                    // Fallback to a solid color material
                    material = UnlitMaterial(color: .blue)
                }
            } else {
                print("❌ Logo image 'logo' not found in bundle")
                // Fallback to a solid color material
                material = UnlitMaterial(color: .red)
            }

            // Create plane with correct aspect ratio
            let mesh = MeshResource.generatePlane(width: logoWidth, height: logoHeight)

            let logoPlane = ModelEntity(mesh: mesh, materials: [material])

            // Make sure the logo faces outward from the wall
            logoPlane.transform.rotation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])

            // Add a slight offset from the wall to prevent z-fighting
            logoPlane.transform.translation.z = 0.01

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

            // Store references for resizing
            currentLogoEntity = logoPlane
            currentLogoAnchor = anchor

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
