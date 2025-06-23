//
//  ContentView.swift
//  ARBanner
//
//  Created by Ashesh Patel on 2025-06-23.
//

// Reminder: Ensure NSCameraUsageDescription and NSMicrophoneUsageDescription are set in Info.plist for AR recording features.

import SwiftUI

struct ContentView: View {
    @State var recorder = ARRecordingController()

    var body: some View {
        ZStack(alignment: .bottom) {
            ARLogoView()
            HStack {
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
                        .background(recorder.isRecording ? Color.red.opacity(0.8) : Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.bottom, 36)
                }
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
