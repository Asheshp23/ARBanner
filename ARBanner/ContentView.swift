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
    var trackingState: ARCamera.TrackingState = .notAvailable
    var isTrackingReady: Bool {
        switch trackingState {
        case .normal:
            return true
        default:
            return false
        }
    }

    func addLogo(_ anchor: AnchorEntity) {
        placedLogos.append(anchor)
        logoPlaced = true
    }

    func restoreLogosToSession(_ arView: ARView) {
        // Note: In a production app, you'd want to persist and restore logo positions
        // For this demo, we'll just track that a logo was placed
    }

    func clearLogos() {
        placedLogos.removeAll()
        logoPlaced = false
    }

    func updateTrackingState(_ state: ARCamera.TrackingState) {
        trackingState = state
    }
}

struct ContentView: View {
    @State var recorder = ARRecordingController()
    @State private var arView: ARView?
    @State private var isSelfieMode = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var arStateManager = ARStateManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            if isSelfieMode {
                SelfieARView(arView: $arView, arStateManager: arStateManager)
            } else {
                ARLogoView(arStateManager: arStateManager)
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
                    Text("Position yourself for a selfie with the logo behind you")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.horizontal)
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

                    // Selfie Mode Toggle
                    Button(action: {
                        isSelfieMode.toggle()
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
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(newPhase)
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
            // Pause AR session when app goes to background
            pauseARSession()
        case .inactive:
            // Handle when app becomes inactive
            break
        case .active:
            // Resume AR session when app becomes active
            break
        @unknown default:
            break
        }
    }

    private func pauseARSession() {
        arView?.session.pause()
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
}

struct SelfieARView: UIViewRepresentable {
    @Binding var arView: ARView?
    let arStateManager: ARStateManager

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)

        // Configure for front camera with optimized settings
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = false // Disable for better performance

        // Only run if session isn't already running to avoid conflicts
        if view.session.currentFrame == nil {
            view.session.run(config, options: [.resetTracking])
        }

        // Store reference to the AR view
        DispatchQueue.main.async {
            arView = view
        }

        // Add cleanup handler
        context.coordinator.arView = view

        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        weak var arView: ARView?

        deinit {
            // Properly pause the AR session
            arView?.session.pause()
        }
    }
}

#Preview {
    ContentView()
}
