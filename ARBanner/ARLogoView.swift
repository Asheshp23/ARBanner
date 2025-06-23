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
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical] // Detect vertical planes (walls)
        config.environmentTexturing = .automatic
        arView.session.run(config)

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

        func setupPlaneVisualization() {
            guard let arView = arView else { return }
            arView.session.delegate = self
        }

        // MARK: - ARSessionDelegate
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical {
                    addPlaneVisualization(for: planeAnchor)
                }
            }
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical {
                    updatePlaneVisualization(for: planeAnchor)
                }
            }
        }

        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    removePlaneVisualization(for: planeAnchor)
                }
            }
        }

        private func addPlaneVisualization(for planeAnchor: ARPlaneAnchor) {
            guard let arView = arView else { return }

            let mesh = MeshResource.generatePlane(width: planeAnchor.planeExtent.width, height: planeAnchor.planeExtent.height)
            var material = UnlitMaterial(color: .blue)
            material.color = .init(tint: .blue.withAlphaComponent(0.3))

            let planeEntity = ModelEntity(mesh: mesh, materials: [material])
            planeEntity.transform.translation = [planeAnchor.planeExtent.rotationX, 0, planeAnchor.planeExtent.rotationZ]

            let anchorEntity = AnchorEntity(anchor: planeAnchor)
            anchorEntity.addChild(planeEntity)

            planeAnchors[planeAnchor.identifier] = planeEntity
            arView.scene.addAnchor(anchorEntity)
        }

        private func updatePlaneVisualization(for planeAnchor: ARPlaneAnchor) {
            guard let planeEntity = planeAnchors[planeAnchor.identifier] else { return }

            let mesh = MeshResource.generatePlane(width: planeAnchor.planeExtent.width, height: planeAnchor.planeExtent.height)
            planeEntity.model?.mesh = mesh
            planeEntity.transform.translation = [planeAnchor.planeExtent.rotationX, 0, planeAnchor.planeExtent.rotationZ]
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
            let mesh = MeshResource.generatePlane(width: 0.4, height: 0.4)

                        let material: Material
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
                    unlitMaterial.color = .texture(texture)
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

            // Orient the logo to face outward from the wall
            let rotation = simd_quatf(transform)
            logoPlane.transform.rotation = rotation

            // Add subtle animation
            let animation = AnimationResource.makeTransform(
                duration: 0.5,
                translation: [0, 0, 0.05],
                scale: [1.1, 1.1, 1.1],
                rotation: rotation
            ).repeated(count: 1)

            logoPlane.playAnimation(animation)

            anchor.addChild(logoPlane)
            arView.scene.addAnchor(anchor)

            // Update state manager
            arStateManager.addLogo(anchor)

            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
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

extension ARPlaneAnchor.PlaneExtent {
    var rotationX: Float { return 0 }
    var rotationZ: Float { return 0 }
}
