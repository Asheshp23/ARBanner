# ARBanner - AR Logo Placement App

A simple iOS AR app that allows users to place logos on walls and take selfies with the placed content.

## Features

- **Wall Detection**: Automatically detects vertical planes (walls) and visualizes them with blue overlay
- **Logo Placement**: Tap on detected walls to place your logo
- **Selfie Mode**: Switch to front camera to take selfies with the placed logo in the background
- **Photo Capture**: Save AR photos directly to your photo library
- **Screen Recording**: Record your AR experience using ReplayKit

## How to Use

### 1. Place a Logo on a Wall

1. Open the app and point your camera at a wall
2. Wait for blue overlay to appear on detected wall surfaces
3. Tap on the wall where you want to place the logo
4. The logo will appear with a subtle animation and haptic feedback

### 2. Take a Selfie with the Logo

1. After placing a logo, tap "Selfie Mode" to switch to the front camera
2. Position yourself so the logo appears behind you in the frame
3. Tap the camera button to capture and save the photo to your library

### 3. Record Your Experience

1. Use "Start Recording" to begin screen recording
2. Interact with the AR content (place logos, switch cameras)
3. Tap "Stop Recording" to end and save/share the recording

## Technical Requirements

- iOS 18.0 or later
- Device with ARKit support (iPhone 6s or newer)
- Camera and photo library permissions
- Face tracking support for selfie mode

## Permissions Required

- **Camera**: For AR functionality and photo capture
- **Microphone**: For video recording with audio
- **Photo Library**: To save captured AR photos

## Troubleshooting

### App won't build or run:

- Ensure your iOS deployment target is set to 18.0 or compatible version
- Make sure you're running on a physical device (AR doesn't work in simulator)
- Verify your development team is properly configured in Xcode

### Logo not appearing:

- Check that the logo image asset is properly imported
- Try different lighting conditions for better wall detection
- Make sure you're tapping on the blue highlighted wall surfaces

### Selfie mode not working:

- Ensure your device supports TrueDepth camera and Face ID/Face tracking
- Make sure you've placed a logo first before switching to selfie mode

## Development Notes

The app uses:

- **ARKit + RealityKit** for AR functionality
- **SwiftUI** for the user interface
- **ReplayKit** for screen recording
- **Photos framework** for saving images

For production use, consider implementing:

- Logo persistence across app sessions
- Multiple logo placement
- Logo customization options
- Cloud storage for AR scenes
