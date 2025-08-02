/// Data models for face tracking
/// 
/// This file contains all the data models used by the Flutter OpenSeeFace plugin.
/// These models complement the generated Rust bridge models with additional
/// Dart-specific functionality and convenience methods.

import 'package:flutter/foundation.dart';
import '../generated/bridge_generated.dart';

// Re-export generated models
export '../generated/bridge_generated.dart';

/// Configuration presets for common use cases
class TrackerConfigPresets {
  /// High accuracy configuration (slower performance)
  static TrackerConfig get highAccuracy => TrackerConfig(
    modelType: ModelType.retinaFace,
    confidenceThreshold: 0.9,
    maxFaces: 2,
    enableLandmarks: true,
    enablePoseEstimation: true,
    enableGazeTracking: true,
    targetFps: 15,
  );

  /// Balanced configuration (good performance and accuracy)
  static TrackerConfig get balanced => TrackerConfig(
    modelType: ModelType.retinaFace,
    confidenceThreshold: 0.8,
    maxFaces: 4,
    enableLandmarks: true,
    enablePoseEstimation: true,
    enableGazeTracking: false,
    targetFps: 30,
  );

  /// High performance configuration (faster, lower accuracy)
  static TrackerConfig get highPerformance => TrackerConfig(
    modelType: ModelType.retinaFace,
    confidenceThreshold: 0.7,
    maxFaces: 2,
    enableLandmarks: true,
    enablePoseEstimation: false,
    enableGazeTracking: false,
    targetFps: 60,
  );

  /// Minimal configuration (basic face detection only)
  static TrackerConfig get minimal => TrackerConfig(
    modelType: ModelType.retinaFace,
    confidenceThreshold: 0.8,
    maxFaces: 1,
    enableLandmarks: false,
    enablePoseEstimation: false,
    enableGazeTracking: false,
    targetFps: 30,
  );
}

/// Helper class for working with facial landmarks
class LandmarkHelper {
  /// Landmark indices for different facial features
  static const Map<String, List<int>> landmarkGroups = {
    'jawLine': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    'rightEyebrow': [17, 18, 19, 20, 21],
    'leftEyebrow': [22, 23, 24, 25, 26],
    'nose': [27, 28, 29, 30, 31, 32, 33, 34, 35],
    'rightEye': [36, 37, 38, 39, 40, 41],
    'leftEye': [42, 43, 44, 45, 46, 47],
    'mouth': [48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67],
  };

  /// Get landmarks for a specific facial feature
  static List<Point2D>? getLandmarksForFeature(
    FacialLandmarks? landmarks,
    String feature,
  ) {
    if (landmarks == null) return null;
    
    final indices = landmarkGroups[feature];
    if (indices == null) return null;

    return indices
        .where((i) => i < landmarks.points.length)
        .map((i) => landmarks.points[i])
        .toList();
  }

  /// Calculate the center point of a facial feature
  static Point2D? getFeatureCenter(
    FacialLandmarks? landmarks,
    String feature,
  ) {
    final points = getLandmarksForFeature(landmarks, feature);
    if (points == null || points.isEmpty) return null;

    final sumX = points.fold<double>(0, (sum, p) => sum + p.x);
    final sumY = points.fold<double>(0, (sum, p) => sum + p.y);

    return Point2D(
      x: sumX / points.length,
      y: sumY / points.length,
    );
  }

  /// Calculate the distance between two landmark points
  static double? getLandmarkDistance(
    FacialLandmarks? landmarks,
    int index1,
    int index2,
  ) {
    if (landmarks == null) return null;
    if (index1 >= landmarks.points.length || index2 >= landmarks.points.length) {
      return null;
    }

    final p1 = landmarks.points[index1];
    final p2 = landmarks.points[index2];

    return _distance2D(p1, p2);
  }

  /// Calculate Euclidean distance between two 2D points
  static double _distance2D(Point2D p1, Point2D p2) {
    final dx = p1.x - p2.x;
    final dy = p1.y - p2.y;
    return (dx * dx + dy * dy).abs().sqrt();
  }
}

/// Helper class for working with head pose
class PoseHelper {
  /// Convert pose angles from radians to degrees
  static HeadPose toDegrees(HeadPose pose) {
    return HeadPose(
      pitch: _radiansToDegrees(pose.pitch),
      yaw: _radiansToDegrees(pose.yaw),
      roll: _radiansToDegrees(pose.roll),
      translation: pose.translation,
      confidence: pose.confidence,
    );
  }

  /// Convert pose angles from degrees to radians
  static HeadPose toRadians(HeadPose pose) {
    return HeadPose(
      pitch: _degreesToRadians(pose.pitch),
      yaw: _degreesToRadians(pose.yaw),
      roll: _degreesToRadians(pose.roll),
      translation: pose.translation,
      confidence: pose.confidence,
    );
  }

  /// Check if head is facing forward (within threshold)
  static bool isFacingForward(HeadPose pose, {double threshold = 15.0}) {
    final degrees = toDegrees(pose);
    return degrees.pitch.abs() < threshold &&
           degrees.yaw.abs() < threshold &&
           degrees.roll.abs() < threshold;
  }

  /// Get head orientation as a descriptive string
  static String getOrientationDescription(HeadPose pose) {
    final degrees = toDegrees(pose);
    
    final pitch = degrees.pitch;
    final yaw = degrees.yaw;
    final roll = degrees.roll;
    
    final List<String> descriptions = [];
    
    // Pitch (up/down)
    if (pitch > 10) {
      descriptions.add('looking up');
    } else if (pitch < -10) {
      descriptions.add('looking down');
    }
    
    // Yaw (left/right)
    if (yaw > 15) {
      descriptions.add('turned right');
    } else if (yaw < -15) {
      descriptions.add('turned left');
    }
    
    // Roll (tilt)
    if (roll > 10) {
      descriptions.add('tilted right');
    } else if (roll < -10) {
      descriptions.add('tilted left');
    }
    
    if (descriptions.isEmpty) {
      return 'facing forward';
    }
    
    return descriptions.join(', ');
  }

  static double _radiansToDegrees(double radians) => radians * 180.0 / 3.14159265359;
  static double _degreesToRadians(double degrees) => degrees * 3.14159265359 / 180.0;
}

/// Helper class for working with eye gaze
class GazeHelper {
  /// Calculate the angle between gaze direction and forward vector
  static double getGazeAngle(Point3D gazeDirection) {
    final forward = Point3D(x: 0, y: 0, z: 1);
    return _angle3D(gazeDirection, forward);
  }

  /// Check if gaze is directed at the camera (within threshold)
  static bool isLookingAtCamera(
    EyeGaze gaze, {
    double threshold = 0.2,
  }) {
    final angle = getGazeAngle(gaze.combinedDirection);
    return angle < threshold;
  }

  /// Get gaze direction as a descriptive string
  static String getGazeDescription(EyeGaze gaze) {
    final direction = gaze.combinedDirection;
    
    if (isLookingAtCamera(gaze)) {
      return 'looking at camera';
    }
    
    final List<String> descriptions = [];
    
    if (direction.x > 0.1) {
      descriptions.add('looking right');
    } else if (direction.x < -0.1) {
      descriptions.add('looking left');
    }
    
    if (direction.y > 0.1) {
      descriptions.add('looking up');
    } else if (direction.y < -0.1) {
      descriptions.add('looking down');
    }
    
    return descriptions.isEmpty ? 'looking straight' : descriptions.join(', ');
  }

  /// Calculate angle between two 3D vectors
  static double _angle3D(Point3D v1, Point3D v2) {
    final dot = v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
    final mag1 = (v1.x * v1.x + v1.y * v1.y + v1.z * v1.z).sqrt();
    final mag2 = (v2.x * v2.x + v2.y * v2.y + v2.z * v2.z).sqrt();
    
    if (mag1 == 0 || mag2 == 0) return 0;
    
    final cosAngle = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return cosAngle.abs().acos();
  }
}

/// Helper class for face tracking statistics
class StatsHelper {
  /// Calculate frames per second from processing times
  static double calculateFPS(List<double> processingTimes) {
    if (processingTimes.isEmpty) return 0;
    
    final averageTime = processingTimes.reduce((a, b) => a + b) / processingTimes.length;
    return averageTime > 0 ? 1000.0 / averageTime : 0;
  }

  /// Calculate average confidence from a list of faces
  static double calculateAverageConfidence(List<Face> faces) {
    if (faces.isEmpty) return 0;
    
    final totalConfidence = faces.fold<double>(0, (sum, face) => sum + face.confidence);
    return totalConfidence / faces.length;
  }

  /// Get performance rating based on FPS and processing time
  static String getPerformanceRating(double fps, double processingTime) {
    if (fps >= 30 && processingTime < 33) {
      return 'Excellent';
    } else if (fps >= 20 && processingTime < 50) {
      return 'Good';
    } else if (fps >= 15 && processingTime < 67) {
      return 'Fair';
    } else {
      return 'Poor';
    }
  }
}

/// Extension methods for working with bounding boxes
extension BoundingBoxExtensions on BoundingBox {
  /// Get the center point of the bounding box
  Point2D get center => Point2D(
    x: x + width / 2,
    y: y + height / 2,
  );

  /// Get the area of the bounding box
  double get area => width * height;

  /// Check if this bounding box contains a point
  bool contains(Point2D point) {
    return point.x >= x &&
           point.x <= x + width &&
           point.y >= y &&
           point.y <= y + height;
  }

  /// Calculate intersection area with another bounding box
  double intersectionArea(BoundingBox other) {
    final left = x > other.x ? x : other.x;
    final top = y > other.y ? y : other.y;
    final right = (x + width) < (other.x + other.width) 
        ? (x + width) 
        : (other.x + other.width);
    final bottom = (y + height) < (other.y + other.height) 
        ? (y + height) 
        : (other.y + other.height);

    if (right <= left || bottom <= top) return 0;
    
    return (right - left) * (bottom - top);
  }

  /// Calculate IoU (Intersection over Union) with another bounding box
  double iou(BoundingBox other) {
    final intersection = intersectionArea(other);
    final union = area + other.area - intersection;
    
    return union > 0 ? intersection / union : 0;
  }
}

/// Camera frame builder for easier frame creation
class CameraFrameBuilder {
  Uint8List? _imageData;
  int? _width;
  int? _height;
  ImageFormat _format = ImageFormat.RGB;
  int _rotation = 0;
  DateTime? _timestamp;

  CameraFrameBuilder imageData(Uint8List data) {
    _imageData = data;
    return this;
  }

  CameraFrameBuilder dimensions(int width, int height) {
    _width = width;
    _height = height;
    return this;
  }

  CameraFrameBuilder format(ImageFormat format) {
    _format = format;
    return this;
  }

  CameraFrameBuilder rotation(int rotation) {
    _rotation = rotation;
    return this;
  }

  CameraFrameBuilder timestamp(DateTime timestamp) {
    _timestamp = timestamp;
    return this;
  }

  CameraFrame build() {
    if (_imageData == null || _width == null || _height == null) {
      throw ArgumentError('Image data, width, and height are required');
    }

    return CameraFrame(
      imageData: _imageData!,
      width: _width!,
      height: _height!,
      format: _format,
      rotation: _rotation,
      timestamp: (_timestamp ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }
}