// ARRecordingController.swift
// ARBanner
//
// Handles ReplayKit-based recording for AR experience

import Foundation
import ReplayKit
import SwiftUI

@Observable
class ARRecordingController: NSObject {
    private let recorder = RPScreenRecorder.shared()
    var isRecording = false

    func startRecording() {
        recorder.startRecording { [weak self] error in
            DispatchQueue.main.async {
                self?.isRecording = (error == nil)
            }
        }
    }

    func stopRecording(completion: @escaping () -> Void) {
        recorder.stopRecording { (previewVC, error) in
            DispatchQueue.main.async {
                self.isRecording = false
                if let previewVC = previewVC,
                   let rootVC = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap({ $0.windows })
                    .first(where: { $0.isKeyWindow })?.rootViewController {
                    previewVC.previewControllerDelegate = self
                    rootVC.present(previewVC, animated: true, completion: nil)
                }
                completion()
            }
        }
    }
}

extension ARRecordingController: RPPreviewViewControllerDelegate {
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true, completion: nil)
    }
}
