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

    func addLogo(_ anchor: AnchorEntity) {
        placedLogos.append(anchor)
        logoPlaced = true
    }

    func restoreLogosToSession(_ arView: ARView) {
        // Note: In a production app, you'd want to persist and restore logo positions
        // For this demo, we'll just track that a logo was placed
    }
}

struct ContentView: View {
    @State var recorder = ARRecordingController()
    @State private var arView: ARView?
    @State private var isSelfieMode = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var arStateManager = ARStateManager()

    var body: some View {
        ZStack(alignment: .bottom) {
            if isSelfieMode {
                SelfieARView(arView: $arView, arStateManager: arStateManager)
            } else {
                ARLogoView(arStateManager: arStateManager)
            }

            VStack(spacing: 16) {
                if !arStateManager.logoPlaced && !isSelfieMode {
                    Text("Point your camera at a wall and tap to place the logo")
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
                    .disabled(!arStateManager.logoPlaced && isSelfieMode)

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
                print("Photo library access denied")
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

        // Configure for front camera
        let config = ARFaceTrackingConfiguration()
        view.session.run(config)

        // Store reference to the AR view
        DispatchQueue.main.async {
            arView = view
        }

        // Restore any previously placed logos
        arStateManager.restoreLogosToSession(view)

        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

#Preview {
    ContentView()
}
