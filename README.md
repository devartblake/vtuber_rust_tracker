# Flutter OpenSeeFace Plugin

A Flutter plugin that provides face tracking capabilities using the openseeface-rs Rust library. This plugin enables real-time face and facial landmark detection with high performance through Rust integration.

## Features

- Real-time face detection and tracking
- Facial landmark detection (68-point model)
- Head pose estimation (rotation, translation)
- Eye gaze tracking
- Mouth shape detection
- Cross-platform support (iOS, Android, Windows, macOS, Linux)
- High performance through Rust implementation
- Asynchronous processing with Dart streams

## Prerequisites

Before setting up this project, ensure you have:

### Required Tools
- Flutter SDK (3.16.0 or later)
- Rust toolchain (1.70.0 or later)
- flutter_rust_bridge_codegen
- Dart SDK (included with Flutter)

### Platform-Specific Requirements

#### Android
- Android Studio
- NDK (r25b or later)
- CMake (3.18.1 or later)

#### iOS
- Xcode 14.0 or later
- iOS deployment target 11.0 or later

#### Desktop (Windows/macOS/Linux)
- Platform-specific build tools
- OpenCV (for camera access)

## Installation & Setup

### 1. Install Rust and Required Tools

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Install flutter_rust_bridge_codegen
cargo install flutter_rust_bridge_codegen
```

### 2. Add Rust Targets (for mobile development)

```bash
# For Android
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android

# For iOS
rustup target add aarch64-apple-ios x86_64-apple-ios aarch64-apple-ios-sim
```

### 3. Clone and Setup Project

```bash
git clone <your-repo-url>
cd flutter_openseeface_plugin

# Get Flutter dependencies
flutter pub get

# Build Rust library and generate bindings
./scripts/build.sh
```

### 4. Platform-Specific Setup

#### Android Setup
1. Open `android/` folder in Android Studio
2. Ensure NDK is installed and configured
3. Update `android/app/build.gradle` if needed

#### iOS Setup
1. Open `ios/Runner.xcworkspace` in Xcode
2. Set minimum deployment target to iOS 11.0
3. Configure signing certificates

## Project Structure

```
flutter_openseeface_plugin/
├── lib/                          # Dart/Flutter code
│   ├── src/
│   │   ├── face_tracker.dart     # Main API
│   │   ├── models/               # Data models
│   │   ├── exceptions/           # Custom exceptions
│   │   └── utils/               # Utility functions
│   ├── flutter_openseeface_plugin.dart
│   └── generated/               # Auto-generated bindings
├── rust/                        # Rust implementation
│   ├── src/
│   │   ├── lib.rs              # Library entry point
│   │   ├── api/                # Flutter bridge API
│   │   ├── face_tracking/      # Core tracking logic
│   │   └── models/             # Rust data structures
│   ├── Cargo.toml
│   └── build.rs               # Build script
├── example/                    # Example Flutter app
├── android/                   # Android-specific code
├── ios/                      # iOS-specific code
├── linux/                   # Linux-specific code
├── macos/                   # macOS-specific code
├── windows/                 # Windows-specific code
├── scripts/                # Build and utility scripts
├── docs/                  # Documentation
└── test/                 # Tests
```

## Development Workflow

### 1. Code Generation
When you modify Rust API files, regenerate bindings:

```bash
flutter_rust_bridge_codegen generate
```

### 2. Building for Development
```bash
# Development build
./scripts/build.sh --debug

# Release build
./scripts/build.sh --release
```

### 3. Running Tests
```bash
# Dart tests
flutter test

# Rust tests
cd rust && cargo test

# Integration tests
flutter test integration_test/
```

### 4. Running Example
```bash
cd example
flutter run
```

## API Usage

### Basic Face Tracking

```dart
import 'package:flutter_openseeface_plugin/flutter_openseeface_plugin.dart';

class FaceTrackingExample extends StatefulWidget {
  @override
  _FaceTrackingExampleState createState() => _FaceTrackingExampleState();
}

class _FaceTrackingExampleState extends State<FaceTrackingExample> {
  late FaceTracker _faceTracker;
  StreamSubscription<List<Face>>? _faceSubscription;

  @override
  void initState() {
    super.initState();
    _initializeFaceTracker();
  }

  Future<void> _initializeFaceTracker() async {
    _faceTracker = FaceTracker();
    await _faceTracker.initialize(TrackerConfig(
      modelType: ModelType.retinaFace,
      confidenceThreshold: 0.8,
      enableLandmarks: true,
      enablePoseEstimation: true,
    ));

    _faceSubscription = _faceTracker.faceStream.listen((faces) {
      setState(() {
        // Update UI with detected faces
      });
    });
  }

  @override
  void dispose() {
    _faceSubscription?.cancel();
    _faceTracker.dispose();
    super.dispose();
  }
}
```

### Processing Camera Frames

```dart
// Process camera frame
await _faceTracker.processFrame(CameraFrame(
  imageData: frameData,
  width: width,
  height: height,
  format: ImageFormat.yuv420,
  timestamp: DateTime.now(),
));
```

## Configuration Options

### TrackerConfig
- `modelType`: Model to use (RetinaFace, etc.)
- `confidenceThreshold`: Detection confidence threshold (0.0-1.0)
- `enableLandmarks`: Enable facial landmark detection
- `enablePoseEstimation`: Enable head pose estimation
- `enableGazeTracking`: Enable eye gaze tracking
- `maxFaces`: Maximum number of faces to track simultaneously

## Performance Considerations

1. **Frame Rate**: Limit processing to 30 FPS for optimal performance
2. **Image Resolution**: Use appropriate resolution (480p-720p recommended)
3. **Threading**: Processing happens on background threads automatically
4. **Memory**: Plugin handles memory management, but dispose properly
5. **Battery**: Face tracking is computationally intensive

## Troubleshooting

### Build Issues
1. Ensure all Rust targets are installed
2. Check NDK/Xcode versions match requirements
3. Clean build directories: `flutter clean && cargo clean`

### Runtime Issues
1. Check camera permissions
2. Verify model files are bundled correctly
3. Monitor memory usage for large image processing

### Platform-Specific Issues
- **Android**: Check NDK configuration in `build.gradle`
- **iOS**: Verify deployment target and signing
- **Desktop**: Ensure OpenCV is properly linked

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Update documentation
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Credits

- [openseeface-rs](https://github.com/ricky26/openseeface-rs) - Rust face tracking library
- [OpenSeeFace](https://github.com/emilianavt/OpenSeeFace) - Original Python implementation
- [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) - Rust-Flutter integration

## Support

For issues and questions:
1. Check existing GitHub issues
2. Review documentation
3. Create a new issue with detailed description and reproduction steps