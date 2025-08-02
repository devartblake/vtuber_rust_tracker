/// Exception handling for the Flutter OpenSeeFace plugin
/// 
/// This file contains all custom exception classes used throughout the plugin.

import 'package:flutter/foundation.dart';

/// Base exception class for all face tracker related errors
abstract class FaceTrackerException implements Exception {
  /// Error message
  final String message;
  
  /// Error type for categorization
  final FaceTrackerErrorType type;
  
  /// Stack trace when the error occurred
  final StackTrace? stackTrace;
  
  /// Timestamp when the error occurred
  final DateTime timestamp;

  const FaceTrackerException(
    this.message,
    this.type, {
    this.stackTrace,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'FaceTrackerException: $message (${type.name})';

  /// Get a user-friendly error message
  String get userMessage {
    switch (type) {
      case FaceTrackerErrorType.notInitialized:
        return 'Face tracker needs to be initialized before use.';
      case FaceTrackerErrorType.invalidConfiguration:
        return 'Invalid configuration settings. Please check your parameters.';
      case FaceTrackerErrorType.cameraError:
        return 'Camera access failed. Please check permissions and try again.';
      case FaceTrackerErrorType.processingError:
        return 'Error processing camera frame. Please try again.';
      case FaceTrackerErrorType.modelError:
        return 'Face detection model error. Please restart the app.';
      case FaceTrackerErrorType.memoryError:
        return 'Insufficient memory. Please close other apps and try again.';
      case FaceTrackerErrorType.platformError:
        return 'Platform-specific error occurred.';
      case FaceTrackerErrorType.invalidState:
        return 'Invalid operation for current state.';
      case FaceTrackerErrorType.networkError:
        return 'Network error occurred while loading resources.';
      case FaceTrackerErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Whether this error is recoverable
  bool get isRecoverable {
    switch (type) {
      case FaceTrackerErrorType.processingError:
      case FaceTrackerErrorType.networkError:
        return true;
      case FaceTrackerErrorType.notInitialized:
      case FaceTrackerErrorType.invalidConfiguration:
      case FaceTrackerErrorType.invalidState:
        return true; // Can be fixed by proper initialization/configuration
      case FaceTrackerErrorType.cameraError:
        return true; // Might be recoverable with permissions
      case FaceTrackerErrorType.modelError:
      case FaceTrackerErrorType.memoryError:
      case FaceTrackerErrorType.platformError:
      case FaceTrackerErrorType.unknown:
        return false;
    }
  }

  /// Error severity level
  ErrorSeverity get severity {
    switch (type) {
      case FaceTrackerErrorType.processingError:
        return ErrorSeverity.low;
      case FaceTrackerErrorType.cameraError:
      case FaceTrackerErrorType.networkError:
        return ErrorSeverity.medium;
      case FaceTrackerErrorType.notInitialized:
      case FaceTrackerErrorType.invalidConfiguration:
      case FaceTrackerErrorType.invalidState:
        return ErrorSeverity.high;
      case FaceTrackerErrorType.modelError:
      case FaceTrackerErrorType.memoryError:
      case FaceTrackerErrorType.platformError:
      case FaceTrackerErrorType.unknown:
        return ErrorSeverity.critical;
    }
  }
}

/// Specific exception types
enum FaceTrackerErrorType {
  notInitialized,
  invalidConfiguration,
  cameraError,
  processingError,
  modelError,
  memoryError,
  platformError,
  invalidState,
  networkError,
  unknown,
}

/// Error severity levels
enum ErrorSeverity {
  low,
  medium,
  high,
  critical,
}

/// General face tracker exception
class GeneralFaceTrackerException extends FaceTrackerException {
  const GeneralFaceTrackerException(
    super.message,
    super.type, {
    super.stackTrace,
    super.timestamp,
  });
}

/// Initialization related exception
class InitializationException extends FaceTrackerException {
  /// The configuration that failed
  final dynamic failedConfig;

  const InitializationException(
    super.message, {
    this.failedConfig,
    super.stackTrace,
    super.timestamp,
  }) : super(FaceTrackerErrorType.notInitialized);

  @override
  String toString() => 'InitializationException: $message';
}

/// Configuration related exception
class ConfigurationException extends FaceTrackerException {
  /// The invalid parameter name
  final String? parameterName;
  
  /// The invalid value
  final dynamic invalidValue;

  const ConfigurationException(
    super.message, {
    this.parameterName,
    this.invalidValue,
    super.stackTrace,
    super.timestamp,
  }) : super(FaceTrackerErrorType.invalidConfiguration);

  @override
  String toString() {
    if (parameterName != null) {
      return 'ConfigurationException: $message (parameter: $parameterName, value: $invalidValue)';
    }
    return 'ConfigurationException: $message';
  }
}

/// Camera access related exception
class CameraException extends FaceTrackerException {
  /// Camera device ID that failed
  final String? cameraId;
  
  /// Platform-specific error code
  final int? errorCode;

  const CameraException(
    super.message, {
    this.cameraId,
    this.errorCode,
    super.stackTrace,
    super.timestamp,
  }) : super(FaceTrackerErrorType.cameraError);

  @override
  String toString() {
    var result = 'CameraException: $message';
    if (cameraId != null) result += ' (camera: $cameraId)';
    if (errorCode != null) result += ' (code: $errorCode)';
    return result;
  }
}

/// Frame processing related exception
class ProcessingException extends FaceTrackerException {
  /// Frame that failed to process
  final dynamic failedFrame;
  
  /// Processing step that failed
  final String? processingStep;

  const ProcessingException(
    super.message, {
    this.failedFrame,
    this.processingStep,
    super.stackTrace,
    super.timestamp,
  }) : super(FaceTrackerErrorType.processingError);

  @override
  String toString() {
    var result = 'ProcessingException: $message';
    if (processingStep != null) result += ' (step: $processingStep)';
    return result;
  }
}

/// Model loading/execution related exception
class ModelException extends FaceTrackerException {
  /// Model name that failed
  final String? modelName;
  
  /// Model version
  final String? modelVersion;

  const ModelException(
    super.message, {
    this.modelName,
    this.modelVersion,
    super.stackTrace,
    super.timestamp,
  }) : super(FaceTrackerErrorType.modelError);

  @override
  String toString() {
    var result = 'ModelException: $message';
    if (modelName != null) result += ' (model: $modelName)';
    if (modelVersion != null) result += ' (version: $modelVersion)';
    return result;
  }
}

/// Memory related exception
class MemoryException extends FaceTrackerException {
  /// Requested memory size in bytes
  final int? requestedBytes;
  
  /// Available memory size in bytes
  final int? availableBytes;

  const MemoryException(
    super.message, {
    this.requestedBytes,
    this.availableBytes,
    super.stackTrace,
    super.timestamp,
  }) : super(FaceTrackerErrorType.memoryError);

  @override
  String toString() {
    var result = 'MemoryException: $message';
    if (requestedBytes != null && availableBytes != null) {
      result += ' (requested: ${_formatBytes(requestedBytes!)}, available: ${_formatBytes(availableBytes!)})';
    }
    return result;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// Platform-specific exception
class PlatformException extends FaceTrackerException {
  /// Platform name
  final String? platform;
  
  /// Platform-specific error code
  final String? platformErrorCode;

  const PlatformException(
    super.message, {
    this.platform,
    this.platformErrorCode,
    super.stackTrace,
    super.timestamp,
  }) : super(FaceTrackerErrorType.platformError);

  @override
  String toString() {
    var result = 'PlatformException: $message';
    if (platform != null) result += ' (platform: $platform)';
    if (platformErrorCode != null) result += ' (code: $platformErrorCode)';
    return result;
  }
}

/// State management related exception
class StateException extends FaceTrackerException {
  /// Current state
  final String? currentState;
  
  /// Expected state
  final String? expectedState;

  const StateException(
    super.message, {
    this.currentState,
    this.expectedState,
    super.stackTrace,
    super.timestamp,
  }) : super(FaceTrackerErrorType.invalidState);

  @override
  String toString() {
    var result = 'StateException: $message';
    if (currentState != null && expectedState != null) {
      result += ' (current: $currentState, expected: $expectedState)';
    }
    return result;
  }
}

/// Network related exception
class NetworkException extends FaceTrackerException {
  /// HTTP status code (if applicable)
  final int? statusCode;
  
  /// URL that failed
  final String? url;

  const NetworkException(
    super.message, {
    this.statusCode,
    this.url,
    super.stackTrace,
    super.timestamp,
  }) : super(FaceTrackerErrorType.networkError);

  @override
  String toString() {
    var result = 'NetworkException: $message';
    if (statusCode != null) result += ' (status: $statusCode)';
    if (url != null) result += ' (url: $url)';
    return result;
  }
}

/// Exception factory for creating exceptions from error types
class ExceptionFactory {
  /// Create an exception from an error type and message
  static FaceTrackerException create(
    FaceTrackerErrorType type,
    String message, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    switch (type) {
      case FaceTrackerErrorType.notInitialized:
        return InitializationException(
          message,
          failedConfig: context?['config'],
          stackTrace: stackTrace,
        );
      
      case FaceTrackerErrorType.invalidConfiguration:
        return ConfigurationException(
          message,
          parameterName: context?['parameter'],
          invalidValue: context?['value'],
          stackTrace: stackTrace,
        );
      
      case FaceTrackerErrorType.cameraError:
        return CameraException(
          message,
          cameraId: context?['cameraId'],
          errorCode: context?['errorCode'],
          stackTrace: stackTrace,
        );
      
      case FaceTrackerErrorType.processingError:
        return ProcessingException(
          message,
          failedFrame: context?['frame'],
          processingStep: context?['step'],
          stackTrace: stackTrace,
        );
      
      case FaceTrackerErrorType.modelError:
        return ModelException(
          message,
          modelName: context?['modelName'],
          modelVersion: context?['modelVersion'],
          stackTrace: stackTrace,
        );
      
      case FaceTrackerErrorType.memoryError:
        return MemoryException(
          message,
          requestedBytes: context?['requestedBytes'],
          availableBytes: context?['availableBytes'],
          stackTrace: stackTrace,
        );
      
      case FaceTrackerErrorType.platformError:
        return PlatformException(
          message,
          platform: context?['platform'],
          platformErrorCode: context?['platformErrorCode'],
          stackTrace: stackTrace,
        );
      
      case FaceTrackerErrorType.invalidState:
        return StateException(
          message,
          currentState: context?['currentState'],
          expectedState: context?['expectedState'],
          stackTrace: stackTrace,
        );
      
      case FaceTrackerErrorType.networkError:
        return NetworkException(
          message,
          statusCode: context?['statusCode'],
          url: context?['url'],
          stackTrace: stackTrace,
        );
      
      case FaceTrackerErrorType.unknown:
        return GeneralFaceTrackerException(
          message,
          type,
          stackTrace: stackTrace,
        );
    }
  }
}

/// Error reporter for collecting and reporting errors
class ErrorReporter {
  static final List<FaceTrackerException> _errorHistory = [];
  static const int _maxHistorySize = 100;

  /// Report an error
  static void report(FaceTrackerException exception) {
    _errorHistory.add(exception);
    
    // Keep only the most recent errors
    if (_errorHistory.length > _maxHistorySize) {
      _errorHistory.removeAt(0);
    }
    
    // Log the error
    debugPrint('FaceTracker Error: ${exception.toString()}');
    if (exception.stackTrace != null) {
      debugPrint('Stack trace: ${exception.stackTrace}');
    }
  }

  /// Get error history
  static List<FaceTrackerException> get errorHistory => 
      List.unmodifiable(_errorHistory);

  /// Get errors by type
  static List<FaceTrackerException> getErrorsByType(FaceTrackerErrorType type) {
    return _errorHistory.where((e) => e.type == type).toList();
  }

  /// Get recent errors (within specified duration)
  static List<FaceTrackerException> getRecentErrors(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _errorHistory.where((e) => e.timestamp.isAfter(cutoff)).toList();
  }

  /// Clear error history
  static void clearHistory() {
    _errorHistory.clear();
  }

  /// Get error statistics
  static Map<String, dynamic> getErrorStats() {
    if (_errorHistory.isEmpty) {
      return {
        'totalErrors': 0,
        'errorsByType': <String, int>{},
        'errorsBySeverity': <String, int>{},
        'mostRecentError': null,
      };
    }

    final errorsByType = <String, int>{};
    final errorsBySeverity = <String, int>{};

    for (final error in _errorHistory) {
      final typeName = error.type.name;
      final severityName = error.severity.name;
      
      errorsByType[typeName] = (errorsByType[typeName] ?? 0) + 1;
      errorsBySeverity[severityName] = (errorsBySeverity[severityName] ?? 0) + 1;
    }

    return {
      'totalErrors': _errorHistory.length,
      'errorsByType': errorsByType,
      'errorsBySeverity': errorsBySeverity,
      'mostRecentError': _errorHistory.last.toString(),
    };
  }
}
