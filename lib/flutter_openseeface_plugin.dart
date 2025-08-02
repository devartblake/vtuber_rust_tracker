/// Flutter OpenSeeFace Plugin
/// 
/// A Flutter plugin for real-time face tracking using the openseeface-rs Rust library.
/// Provides face detection, landmark tracking, pose estimation, and gaze tracking.
library flutter_openseeface_plugin;

// Core exports
export 'src/face_tracker.dart';
export 'src/models/models.dart';
export 'src/exceptions/exceptions.dart';
export 'src/utils/utils.dart';

// Generated bindings
export 'generated/bridge_generated.dart' hide initializeApi;

/// Plugin version
const String pluginVersion = '0.1.0';

/// Supported platforms
enum SupportedPlatform {
  android,
  ios,
  windows,
  macos,
  linux,
}

/// Check if the current platform is supported
bool get isPlatformSupported {
  return [
    SupportedPlatform.android,
    SupportedPlatform.ios,
    SupportedPlatform.windows,
    SupportedPlatform.macos,
    SupportedPlatform.linux,
  ].any((platform) => _isCurrentPlatform(platform));
}

bool _isCurrentPlatform(SupportedPlatform platform) {
  // This would be implemented based on dart:io Platform checks
  // For now, return true as a placeholder
  return true;
}
