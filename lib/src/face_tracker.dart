import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

import '../generated/bridge_generated.dart';
import 'models/models.dart';
import 'exceptions/exceptions.dart';
import 'utils/platform_utils.dart';

/// Main face tracker class that provides the high-level API for face tracking
class FaceTracker {
  static final RustLib _rustLib = RustLib.instance;
  
  bool _isInitialized = false;
  bool _isDisposed = false;
  TrackerConfig? _config;
  StreamSubscription<List<Face>>? _faceStreamSubscription;
  
  // Stream controllers for face tracking events
  final StreamController<List<Face>> _faceController = 
      StreamController<List<Face>>.broadcast();
  final StreamController<TrackerStatus> _statusController = 
      StreamController<TrackerStatus>.broadcast();
  final StreamController<FaceTrackerException> _errorController = 
      StreamController<FaceTrackerException>.broadcast();

  /// Stream of detected faces
  Stream<List<Face>> get faceStream => _faceController.stream;
  
  /// Stream of tracker status updates
  Stream<TrackerStatus> get statusStream => _statusController.stream;
  
  /// Stream of errors that occur during tracking
  Stream<FaceTrackerException> get errorStream => _errorController.stream;

  /// Whether the tracker is initialized
  bool get isInitialized => _isInitialized && !_isDisposed;

  /// Current tracker configuration
  TrackerConfig? get config => _config;

  /// Initialize the face tracker with configuration
  Future<void> initialize(TrackerConfig config) async {
    if (_isDisposed) {
      throw FaceTrackerException(
        'Cannot initialize disposed tracker',
        FaceTrackerErrorType.invalidState,
      );
    }

    if (_isInitialized) {
      await dispose();
    }

    try {
      // Validate configuration
      _validateConfig(config);

      // Initialize the Rust library
      await _rustLib.initializeTracker(config: config);
      
      _config = config;
      _isInitialized = true;

      debugPrint('FaceTracker initialized successfully');
      
      // Emit initial status
      _emitStatus();
      
    } catch (e) {
      final exception = _handleError(e, 'Failed to initialize tracker');
      _errorController.add(exception);
      throw exception;
    }
  }

  /// Process a single camera frame
  Future<List<Face>> processFrame(CameraFrame frame) async {
    _ensureInitialized();
    
    try {
      final faces = await _rustLib.processFrame(frame: frame);
      
      // Emit faces to stream
      _faceController.add(faces);
      
      // Update status
      _emitStatus();
      
      return faces;
    } catch (e) {
      final exception = _handleError(e, 'Failed to process frame');
      _errorController.add(exception);
      throw exception;
    }
  }

  /// Start continuous face tracking with a stream of frames
  Future<void> startTracking() async {
    _ensureInitialized();
    
    if (_faceStreamSubscription != null) {
      await stopTracking();
    }

    try {
      final stream = await _rustLib.startFaceTrackingStream();
      
      _faceStreamSubscription = stream.listen(
        (faces) {
          _faceController.add(faces);
          _emitStatus();
        },
        onError: (error) {
          final exception = _handleError(error, 'Error in face tracking stream');
          _errorController.add(exception);
        },
      );

      debugPrint('Face tracking started');
      
    } catch (e) {
      final exception = _handleError(e, 'Failed to start tracking');
      _errorController.add(exception);
      throw exception;
    }
  }

  /// Stop continuous face tracking
  Future<void> stopTracking() async {
    if (_faceStreamSubscription != null) {
      await _faceStreamSubscription!.cancel();
      _faceStreamSubscription = null;
    }

    try {
      await _rustLib.stopTracking();
      debugPrint('Face tracking stopped');
    } catch (e) {
      final exception = _handleError(e, 'Failed to stop tracking');
      _errorController.add(exception);
      // Don't throw here as we want to ensure cleanup continues
    }
  }

  /// Get current tracker status
  Future<TrackerStatus> getStatus() async {
    try {
      return await _rustLib.getTrackerStatus();
    } catch (e) {
      final exception = _handleError(e, 'Failed to get tracker status');
      _errorController.add(exception);
      throw exception;
    }
  }

  /// Process multiple frames in batch (for better performance)
  Future<List<List<Face>>> processFramesBatch(List<CameraFrame> frames) async {
    _ensureInitialized();
    
    final results = <List<Face>>[];
    
    for (final frame in frames) {
      try {
        final faces = await processFrame(frame);
        results.add(faces);
      } catch (e) {
        // For batch processing, we add empty result and continue
        results.add(<Face>[]);
        final exception = _handleError(e, 'Failed to process frame in batch');
        _errorController.add(exception);
      }
    }
    
    return results;
  }

  /// Update tracker configuration (requires re-initialization)
  Future<void> updateConfig(TrackerConfig newConfig) async {
    if (_isDisposed) {
      throw FaceTrackerException(
        'Cannot update config of disposed tracker',
        FaceTrackerErrorType.invalidState,
      );
    }

    final wasTracking = _faceStreamSubscription != null;
    
    // Stop current tracking
    if (wasTracking) {
      await stopTracking();
    }
    
    // Re-initialize with new config
    await initialize(newConfig);
    
    // Restart tracking if it was active
    if (wasTracking) {
      await startTracking();
    }
  }

  /// Dispose of the tracker and clean up resources
  Future<void> dispose() async {
    if (_isDisposed) return;

    try {
      // Stop tracking first
      await stopTracking();
      
      // Dispose Rust resources
      if (_isInitialized) {
        await _rustLib.dispose();
      }
      
      // Close stream controllers
      await _faceController.close();
      await _statusController.close();
      await _errorController.close();
      
      _isInitialized = false;
      _isDisposed = true;
      _config = null;
      
      debugPrint('FaceTracker disposed');
      
    } catch (e) {
      debugPrint('Error during FaceTracker disposal: $e');
      // Continue with disposal even if there's an error
      _isDisposed = true;
    }
  }

  /// Validate tracker configuration
  void _validateConfig(TrackerConfig config) {
    if (config.confidenceThreshold < 0.0 || config.confidenceThreshold > 1.0) {
      throw FaceTrackerException(
        'Confidence threshold must be between 0.0 and 1.0',
        FaceTrackerErrorType.invalidConfiguration,
      );
    }
    
    if (config.maxFaces <= 0) {
      throw FaceTrackerException(
        'Max faces must be greater than 0',
        FaceTrackerErrorType.invalidConfiguration,
      );
    }
    
    if (config.targetFps <= 0 || config.targetFps > 60) {
      throw FaceTrackerException(
        'Target FPS must be between 1 and 60',
        FaceTrackerErrorType.invalidConfiguration,
      );
    }
  }

  /// Ensure tracker is initialized before operations
  void _ensureInitialized() {
    if (_isDisposed) {
      throw FaceTrackerException(
        'Tracker has been disposed',
        FaceTrackerErrorType.invalidState,
      );
    }
    
    if (!_isInitialized) {
      throw FaceTrackerException(
        'Tracker is not initialized. Call initialize() first.',
        FaceTrackerErrorType.notInitialized,
      );
    }
  }

  /// Handle errors and convert them to appropriate exceptions
  FaceTrackerException _handleError(dynamic error, String context) {
    debugPrint('FaceTracker error: $context - $error');
    
    if (error is FaceTrackerException) {
      return error;
    }
    
    // Convert Rust errors to appropriate exceptions
    if (error.toString().contains('TrackerNotInitialized')) {
      return FaceTrackerException(
        'Tracker is not initialized',
        FaceTrackerErrorType.notInitialized,
      );
    }
    
    if (error.toString().contains('ProcessingError')) {
      return FaceTrackerException(
        'Frame processing failed: ${error.toString()}',
        FaceTrackerErrorType.processingError,
      );
    }
    
    if (error.toString().contains('CameraError')) {
      return FaceTrackerException(
        'Camera error: ${error.toString()}',
        FaceTrackerErrorType.cameraError,
      );
    }
    
    // Generic error
    return FaceTrackerException(
      '$context: ${error.toString()}',
      FaceTrackerErrorType.unknown,
    );
  }

  /// Emit current tracker status
  void _emitStatus() {
    if (_isDisposed) return;
    
    getStatus().then((status) {
      if (!_statusController.isClosed) {
        _statusController.add(status);
      }
    }).catchError((error) {
      debugPrint('Failed to emit status: $error');
    });
  }
}

/// Extension methods for CameraFrame
extension CameraFrameExtensions on CameraFrame {
  /// Create a CameraFrame from raw image data
  static CameraFrame fromBytes({
    required Uint8List imageData,
    required int width,
    required int height,
    required ImageFormat format,
    int rotation = 0,
    DateTime? timestamp,
  }) {
    return CameraFrame(
      imageData: imageData,
      width: width,
      height: height,
      format: format,
      rotation: rotation,
      timestamp: (timestamp ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  /// Validate frame data
  bool get isValid {
    if (width <= 0 || height <= 0) return false;
    if (imageData.isEmpty) return false;
    
    // Check expected data size based on format
    final expectedSize = _getExpectedDataSize();
    return imageData.length >= expectedSize;
  }

  /// Get expected data size for the image format
  int _getExpectedDataSize() {
    switch (format) {
      case ImageFormat.RGB:
        return width * height * 3;
      case ImageFormat.RGBA:
        return width * height * 4;
      case ImageFormat.YUV420:
        return (width * height * 3) ~/ 2;
      case ImageFormat.NV21:
        return (width * height * 3) ~/ 2;
      case ImageFormat.BGRA:
        return width * height * 4;
    }
  }
}

/// Utility methods for working with faces
extension FaceExtensions on Face {
  /// Check if this face has high confidence
  bool get hasHighConfidence => confidence >= 0.8;
  
  /// Check if landmarks are available and valid
  bool get hasValidLandmarks => 
      landmarks != null && landmarks!.points.length >= 68;
  
  /// Check if pose estimation is available
  bool get hasPose => pose != null;
  
  /// Check if gaze tracking is available
  bool get hasGaze => gaze != null;
  
  /// Get face center point
  Point2D get center => Point2D(
    x: boundingBox.x + boundingBox.width / 2,
    y: boundingBox.y + boundingBox.height / 2,
  );
  
  /// Get face area
  double get area => boundingBox.width * boundingBox.height;
}
