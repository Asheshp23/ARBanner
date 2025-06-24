//
//  ContentView.swift
//  ARBanner
//
//  Created by Ashesh Patel on 2025-06-23.
//

// Reminder: Ensure NSCameraUsageDescription and NSMicrophoneUsageDescription are set in Info.plist for AR recording features.

import SwiftUI
import ARKit
import Photos
import RealityKit

@Observable
class ARStateManager {
    var placedLogos: [AnchorEntity] = []
    var logoPlaced = false
    var logoTransform: simd_float4x4?
    var trackingState: ARCamera.TrackingState = .notAvailable
    private let worldMapURL = getDocumentsDirectory().appendingPathComponent("ARWorldMap.data")

    var isTrackingReady: Bool {
        switch trackingState {
        case .normal:
            return true
        default:
            return false
        }
    }

    func addLogo(_ anchor: AnchorEntity, transform: simd_float4x4) {
        placedLogos.append(anchor)
        logoPlaced = true
        logoTransform = transform
        print("✅ Logo added at position, transform saved")

        // Save world map after logo placement
        saveWorldMapIfSupported()
    }

    func restoreLogosToSession(_ arView: ARView) {
        // First try to load a saved world map
        if loadWorldMapIfSupported(arView) {
            print("🗺️ Attempting to restore from saved world map")
            return
        }

        // Fallback to transform-based restoration
        guard let transform = logoTransform, logoPlaced else {
            print("No logo transform to restore")
            return
        }

        // Don't restore if there are already logos in the scene
        if !placedLogos.isEmpty {
            print("Logos already exist in scene, skipping restore")
            return
        }

        print("🔄 Restoring logo to AR session using saved transform")
        createLogoAt(transform: transform, in: arView)
    }

    private func createLogoAt(transform: simd_float4x4, in arView: ARView) {
        // Clear any existing logos first
        clearLogosFromScene(arView)

        let anchor = AnchorEntity(world: transform)

        // Load logo image and create the same logo as in ARLogoView
        let material: RealityKit.Material
        var logoWidth: Float = 0.8
        var logoHeight: Float = 0.8

        if let logoImage = UIImage(named: "logo") {
            let imageSize = logoImage.size
            let aspectRatio = Float(imageSize.width / imageSize.height)
            let baseSize: Float = 0.6

            if aspectRatio > 1.0 {
                logoWidth = baseSize * aspectRatio
                logoHeight = baseSize
            } else {
                logoWidth = baseSize
                logoHeight = baseSize / aspectRatio
            }

            do {
                let texture = try TextureResource.generate(from: logoImage.cgImage!, options: .init(semantic: .color))
                var unlitMaterial = UnlitMaterial()
                unlitMaterial.color = .init(texture: .init(texture))
                unlitMaterial.blending = .transparent(opacity: 1.0)
                material = unlitMaterial
            } catch {
                material = UnlitMaterial(color: .blue)
            }
        } else {
            material = UnlitMaterial(color: .red)
        }

        let mesh = MeshResource.generatePlane(width: logoWidth, height: logoHeight)
        let logoPlane = ModelEntity(mesh: mesh, materials: [material])

        // Apply the same transform properties as in ARLogoView
        logoPlane.transform.rotation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        logoPlane.transform.translation.z = 0.01

        // Ensure normal scale (no animation needed for restoration)
        logoPlane.transform.scale = [1.0, 1.0, 1.0]

        anchor.addChild(logoPlane)
        arView.scene.addAnchor(anchor)

        // Update the placed logos array
        placedLogos.append(anchor)
        print("✅ Logo restored successfully with correct scale")
    }

    func clearLogos() {
        placedLogos.removeAll()
        logoPlaced = false
        logoTransform = nil

        // Also remove saved world map
        removeWorldMap()

        print("🗑️ Cleared all logos and reset state")
    }

    func clearLogosFromScene(_ arView: ARView) {
        print("🗑️ Clearing \(placedLogos.count) logos from AR scene")
        for anchor in placedLogos {
            arView.scene.removeAnchor(anchor)
            print("🗑️ Removed anchor from scene")
        }
        placedLogos.removeAll()
    }

    func resetForCameraSwitch() {
        // Keep the logo state and transform, but clear the anchor references
        // since they'll be invalid in the new AR session
        placedLogos.removeAll()
        print("🔄 Reset logo anchors for camera switch (keeping position)")
    }

    func updateTrackingState(_ state: ARCamera.TrackingState) {
        trackingState = state
    }

    func resetState() {
        // Complete reset - used when app starts
        clearLogos()
        trackingState = .notAvailable
        print("🔄 Complete state reset")
    }

    // MARK: - ARWorldMap Persistence (iOS 12+)

    private func saveWorldMapIfSupported() {
        guard #available(iOS 12.0, *) else {
            print("⚠️ ARWorldMap persistence requires iOS 12+")
            return
        }

        // We'll trigger this from the AR session, not here directly
        print("📱 ARWorldMap persistence available")
    }

    func saveWorldMap(from session: ARSession) {
        guard #available(iOS 12.0, *) else { return }

        session.getCurrentWorldMap { [weak self] worldMap, error in
            guard let worldMap = worldMap else {
                print("❌ Failed to get world map: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
                try data.write(to: self?.worldMapURL ?? URL(fileURLWithPath: ""))
                print("💾 World map saved successfully")
            } catch {
                print("❌ Failed to save world map: \(error.localizedDescription)")
            }
        }
    }

    func loadWorldMapIfSupported(_ arView: ARView) -> Bool {
        guard #available(iOS 12.0, *) else { return false }

        guard FileManager.default.fileExists(atPath: worldMapURL.path) else {
            print("📭 No saved world map found")
            return false
        }

        do {
            let data = try Data(contentsOf: worldMapURL)
            guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
                print("❌ Failed to unarchive world map")
                return false
            }

            let config = ARWorldTrackingConfiguration()
            config.planeDetection = [.vertical]
            config.environmentTexturing = .none
            config.isLightEstimationEnabled = false
            config.initialWorldMap = worldMap

            arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            print("🗺️ Loaded saved world map, attempting relocalization")
            return true

        } catch {
            print("❌ Failed to load world map: \(error.localizedDescription)")
            return false
        }
    }

    private func removeWorldMap() {
        if FileManager.default.fileExists(atPath: worldMapURL.path) {
            try? FileManager.default.removeItem(at: worldMapURL)
            print("🗑️ Removed saved world map")
        }
    }
}

// Helper function for getting documents directory
private func getDocumentsDirectory() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
}

struct ContentView: View {
    @State var recorder = ARRecordingController()
    @State private var arView: ARView?
    @State private var mainARView: ARView? // For back camera
    @State private var selfieARView: ARView? // For front camera
    @State private var isSelfieMode = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var arStateManager = ARStateManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            if isSelfieMode {
                SelfieARView(arView: $selfieARView, arStateManager: arStateManager)
                    .onAppear {
                        switchToSelfieMode()
                    }
            } else {
                ARLogoView(arView: $mainARView, arStateManager: arStateManager)
                    .onAppear {
                        switchToBackCamera()
                    }
            }

            VStack(spacing: 16) {
                // AR Tracking Status
                if !isSelfieMode {
                    HStack {
                        Circle()
                            .fill(arStateManager.isTrackingReady ? .green : .orange)
                            .frame(width: 8, height: 8)
                        Text(trackingStatusText)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.7))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                if !arStateManager.logoPlaced && !isSelfieMode {
                    Text(arStateManager.isTrackingReady ? "Point your camera at a wall and tap to place the logo" : "Move your device slowly to scan the environment")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.horizontal)
                } else if isSelfieMode && arStateManager.logoPlaced {
                    if ARFaceTrackingConfiguration.isSupported {
                        Text("Position yourself for a selfie with the logo behind you")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.7))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    } else {
                        Text("Face tracking not supported on this device. Selfie mode may not work properly.")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.7))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }

                HStack(spacing: 20) {
                    // Recording Button
                    Button(action: {
                        if recorder.isRecording {
                            recorder.stopRecording() {}
                        } else {
                            recorder.startRecording()
                        }
                    }) {
                        Text(recorder.isRecording ? "Stop Recording" : "Start Recording")
                            .font(.headline)
                            .padding()
                            .frame(minWidth: 140)
                            .background(recorder.isRecording ? Color.red.opacity(0.8) : Color.blue.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    // Clear Logo Button (only visible when logo is placed and not in selfie mode)
                    if arStateManager.logoPlaced && !isSelfieMode {
                        Button(action: {
                            clearLogo()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear Logo")
                            }
                            .font(.headline)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }

                    // Selfie Mode Toggle
                    Button(action: {
                        toggleCameraMode()
                    }) {
                        HStack {
                            Image(systemName: isSelfieMode ? "camera.fill" : "camera.rotate.fill")
                            Text(isSelfieMode ? "Back Camera" : "Selfie Mode")
                        }
                        .font(.headline)
                        .padding()
                        .background(isSelfieMode ? Color.green.opacity(0.8) : Color.orange.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!arStateManager.logoPlaced && !isSelfieMode)
                    .opacity((!arStateManager.logoPlaced && !isSelfieMode) ? 0.6 : 1.0)

                    // Photo Capture Button (only visible in selfie mode)
                    if isSelfieMode {
                        Button(action: {
                            capturePhoto()
                        }) {
                            Image(systemName: "camera.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .background(Circle().fill(.black.opacity(0.7)))
                                .padding()
                        }
                    }
                }
                .padding(.bottom, 36)
            }
        }
        .ignoresSafeArea()
        .alert("Camera", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            requestPhotoLibraryPermission()
            // Reset state when app starts
            arStateManager.resetState()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    private func toggleCameraMode() {
        // Stop recording if active
        if recorder.isRecording {
            recorder.stopRecording() {}
        }

        // Pause current session before switching
        if isSelfieMode {
            selfieARView?.session.pause()
            print("Pausing selfie session, switching to back camera")
        } else {
            mainARView?.session.pause()
            print("Pausing main session, switching to selfie mode")
        }

        // Delay to ensure session is properly paused before switching
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSelfieMode.toggle()
        }
    }

    private func switchToSelfieMode() {
        print("Switching to selfie mode")
        // Ensure main AR view is paused
        mainARView?.session.pause()

        // Don't reset logo state - just clear the anchor references since they're invalid in the new session
        arStateManager.resetForCameraSwitch()

        // Update the current arView reference for photo capture
        arView = selfieARView

        // Small delay before starting selfie session
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            resumeSelfieSession()
        }
    }

    private func switchToBackCamera() {
        print("Switching to back camera")
        // Ensure selfie AR view is paused
        selfieARView?.session.pause()

        // Update the current arView reference
        arView = mainARView

        // Small delay before starting main session
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            resumeMainSession()

            // Only restore logo if we have a saved transform and no logos currently in the scene
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let mainARView = mainARView, arStateManager.logoPlaced && arStateManager.placedLogos.isEmpty {
                    print("🔄 Restoring logo after camera switch")
                    arStateManager.restoreLogosToSession(mainARView)
                }
            }
        }
    }

    private var trackingStatusText: String {
        switch arStateManager.trackingState {
        case .normal:
            return "AR Ready"
        case .notAvailable:
            return "AR Starting..."
        case .limited(let reason):
            switch reason {
            case .initializing:
                return "Initializing AR..."
            case .excessiveMotion:
                return "Move device slower"
            case .insufficientFeatures:
                return "Point at textured surface"
            case .relocalizing:
                return "Relocating..."
            @unknown default:
                return "AR Limited"
            }
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // Pause all AR sessions when app goes to background
            pauseAllARSessions()
        case .inactive:
            // Handle when app becomes inactive
            pauseAllARSessions()
        case .active:
            // Resume appropriate AR session when app becomes active
            resumeCurrentARSession()
        @unknown default:
            break
        }
    }

    private func pauseAllARSessions() {
        mainARView?.session.pause()
        selfieARView?.session.pause()
    }

    private func resumeCurrentARSession() {
        // Small delay to ensure proper initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if isSelfieMode {
                resumeSelfieSession()
            } else {
                resumeMainSession()
            }
        }
    }

    private func resumeMainSession() {
        guard let mainARView = mainARView else { return }

        // First try to restore from saved world map
        if arStateManager.loadWorldMapIfSupported(mainARView) {
            print("🗺️ Attempted to load saved world map")
            return
        }

        // Fallback to regular AR session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical]
        config.environmentTexturing = .none
        config.isLightEstimationEnabled = false

        mainARView.session.run(config, options: [.resetTracking])
        print("📷 Started regular AR session (no saved world map)")
    }

    private func resumeSelfieSession() {
        guard let selfieARView = selfieARView else { return }

        if ARFaceTrackingConfiguration.isSupported {
            let config = ARFaceTrackingConfiguration()
            config.isLightEstimationEnabled = false
            config.worldAlignment = .gravity
            selfieARView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            print("✅ Resumed face tracking configuration (front camera)")
        } else {
            print("⚠️ Face tracking not supported - selfie mode may not work properly")
            // Face tracking not available, can't use front camera with world tracking
        }
    }

    private func pauseARSession() {
        // This method is kept for backward compatibility but now uses the improved logic
        pauseAllARSessions()
    }

    private func capturePhoto() {
        guard let arView = arView else {
            alertMessage = "AR view not available"
            showingAlert = true
            return
        }

        arView.snapshot(saveToHDR: false) { image in
            guard let image = image else {
                DispatchQueue.main.async {
                    alertMessage = "Failed to capture photo"
                    showingAlert = true
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        alertMessage = "Photo saved to your photo library!"
                        showingAlert = true

                        // Provide haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                    } else {
                        alertMessage = "Failed to save photo: \(error?.localizedDescription ?? "Unknown error")"
                        showingAlert = true
                    }
                }
            }
        }
    }

    private func requestPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            switch status {
            case .authorized, .limited:
                print("Photo library access granted")
            case .denied, .restricted:
                DispatchQueue.main.async {
                    alertMessage = "Photo library access denied. Please enable it in Settings to save photos."
                    showingAlert = true
                }
            case .notDetermined:
                print("Photo library access not determined")
            @unknown default:
                print("Unknown photo library authorization status")
            }
        }
    }

    private func clearLogo() {
        print("🗑️ User requested to clear logo")

        // Clear from the appropriate AR view based on current mode
        let currentARView = isSelfieMode ? selfieARView : mainARView

        if let activeARView = currentARView {
            print("🗑️ Clearing logos from \(isSelfieMode ? "selfie" : "main") AR view")
            arStateManager.clearLogosFromScene(activeARView)
        } else {
            print("⚠️ No active AR view found")
        }

        // Also try clearing from the general arView reference
        if let generalARView = arView {
            print("🗑️ Also clearing from general AR view reference")
            arStateManager.clearLogosFromScene(generalARView)
        }

        // Reset state (this also removes the world map)
        arStateManager.clearLogos()

        print("✅ Logo cleared by user - state reset")
    }
}

struct SelfieARView: UIViewRepresentable {
    @Binding var arView: ARView?
    let arStateManager: ARStateManager

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)

        configureARSession(for: view)

        // Store reference to the AR view
        DispatchQueue.main.async {
            arView = view
        }

        // Add cleanup handler
        context.coordinator.arView = view
        view.session.delegate = context.coordinator

        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Only restart if session is not running
        if uiView.session.currentFrame == nil {
            configureARSession(for: uiView)
        }
    }

    private func configureARSession(for arView: ARView) {
        // Check if face tracking is supported (this uses front camera by default)
        if ARFaceTrackingConfiguration.isSupported {
            let config = ARFaceTrackingConfiguration()
            config.isLightEstimationEnabled = false
            config.worldAlignment = .gravity

            arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            print("✅ Started face tracking configuration (front camera)")
        } else {
            // Face tracking not supported, but we can still try to display the front camera view
            // Note: ARWorldTrackingConfiguration always uses back camera, so this is a limitation
            print("⚠️ Face tracking not supported on this device")

            // Create a basic camera view without AR features
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = []
            config.environmentTexturing = .none
            config.isLightEstimationEnabled = false

            arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?

        deinit {
            arView?.session.pause()
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            print("❌ Selfie AR Session failed: \(error.localizedDescription)")

            // Try to restart with a simpler configuration
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard let arView = self.arView else { return }

                if ARFaceTrackingConfiguration.isSupported {
                    let config = ARFaceTrackingConfiguration()
                    config.isLightEstimationEnabled = false
                    arView.session.run(config, options: [.resetTracking])
                }
            }
        }

        func sessionWasInterrupted(_ session: ARSession) {
            print("Selfie AR Session was interrupted")
        }

        func sessionInterruptionEnded(_ session: ARSession) {
            print("Selfie AR Session interruption ended - restarting")
            guard let arView = arView else { return }

            if ARFaceTrackingConfiguration.isSupported {
                let config = ARFaceTrackingConfiguration()
                config.isLightEstimationEnabled = false
                arView.session.run(config, options: [.resetTracking])
            }
        }
    }
}

#Preview {
    ContentView()
}
