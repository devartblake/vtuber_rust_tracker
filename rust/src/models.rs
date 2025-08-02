//! Data models for face tracking
//! 
//! This module contains all the data structures used for face tracking,
//! including face data, landmarks, pose information, etc.

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// Supported model types for face detection
#[frb(dart_metadata=("freezed"))]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ModelType {
    /// RetinaFace model (recommended)
    RetinaFace,
    /// MTCNN model (fallback)
    MTCNN,
}

/// Image format for camera frames
#[frb(dart_metadata=("freezed"))]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ImageFormat {
    /// RGB 24-bit format
    RGB,
    /// RGBA 32-bit format
    RGBA,
    /// YUV420 format (common for camera)
    YUV420,
    /// NV21 format (Android camera)
    NV21,
    /// BGRA format (iOS camera)
    BGRA,
}

/// Camera frame data
#[frb(dart_metadata=("freezed", "immutable"))]
#[derive(Debug, Clone)]
pub struct CameraFrame {
    /// Image data bytes
    pub image_data: Vec<u8>,
    /// Frame width in pixels
    pub width: u32,
    /// Frame height in pixels
    pub height: u32,
    /// Image format
    pub format: ImageFormat,
    /// Frame timestamp in milliseconds since epoch
    pub timestamp: i64,
    /// Camera rotation (0, 90, 180, 270 degrees)
    pub rotation: u32,
}

/// 2D point coordinates
#[frb(dart_metadata=("freezed", "immutable"))]
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Point2D {
    pub x: f32,
    pub y: f32,
}

/// 3D point coordinates
#[frb(dart_metadata=("freezed", "immutable"))]
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Point3D {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

/// Bounding box for face detection
#[frb(dart_metadata=("freezed", "immutable"))]
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct BoundingBox {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}

/// Facial landmarks (68-point model)
#[frb(dart_metadata=("freezed", "immutable"))]
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct FacialLandmarks {
    /// All 68 landmark points
    pub points: Vec<Point2D>,
    /// Confidence scores for each landmark
    pub confidences: Vec<f32>,
}

impl FacialLandmarks {
    /// Get jaw line points (0-16)
    pub fn jaw_line(&self) -> &[Point2D] {
        &self.points[0..17]
    }

    /// Get right eyebrow points (17-21)
    pub fn right_eyebrow(&self) -> &[Point2D] {
        &self.points[17..22]
    }

    /// Get left eyebrow points (22-26)
    pub fn left_eyebrow(&self) -> &[Point2D] {
        &self.points[22..27]
    }

    /// Get nose points (27-35)
    pub fn nose(&self) -> &[Point2D] {
        &self.points[27..36]
    }

    /// Get right eye points (36-41)
    pub fn right_eye(&self) -> &[Point2D] {
        &self.points[36..42]
    }

    /// Get left eye points (42-47)
    pub fn left_eye(&self) -> &[Point2D] {
        &self.points[42..48]
    }

    /// Get mouth points (48-67)
    pub fn mouth(&self) -> &[Point2D] {
        &self.points[48..68]
    }
}

/// Head pose estimation
#[frb(dart_metadata=("freezed", "immutable"))]
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct HeadPose {
    /// Rotation around X-axis (pitch) in degrees
    pub pitch: f32,
    /// Rotation around Y-axis (yaw) in degrees
    pub yaw: f32,
    /// Rotation around Z-axis (roll) in degrees
    pub roll: f32,
    /// Translation vector
    pub translation: Point3D,
    /// Pose confidence (0.0 - 1.0)
    pub confidence: f32,
}

/// Eye gaze information
#[frb(dart_metadata=("freezed", "immutable"))]
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct EyeGaze {
    /// Left eye gaze direction (normalized)
    pub left_eye_direction: Point3D,
    /// Right eye gaze direction (normalized)
    pub right_eye_direction: Point3D,
    /// Combined gaze direction
    pub combined_direction: Point3D,
    /// Gaze confidence (0.0 - 1.0)
    pub confidence: f32,
}

/// Detected face information
#[frb(dart_metadata=("freezed", "immutable"))]
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Face {
    /// Unique face ID for tracking
    pub id: u32,
    /// Face bounding box
    pub bounding_box: BoundingBox,
    /// Detection confidence (0.0 - 1.0)
    pub confidence: f32,
    /// Facial landmarks (if enabled)
    pub landmarks: Option<FacialLandmarks>,
    /// Head pose estimation (if enabled)
    pub pose: Option<HeadPose>,
    /// Eye gaze information (if enabled)
    pub gaze: Option<EyeGaze>,
    /// Frame timestamp when detected
    pub timestamp: i64,
}

/// Tracker status information
#[frb(dart_metadata=("freezed", "immutable"))]
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TrackerStatus {
    /// Whether tracker is initialized
    pub is_initialized: bool,
    /// Whether tracker is currently running
    pub is_running: bool,
    /// Total frames processed
    pub frames_processed: u64,
    /// Average processing FPS
    pub average_fps: f32,
    /// Last error message (if any)
    pub last_error: Option<String>,
}

/// Face tracking statistics
#[frb(dart_metadata=("freezed", "immutable"))]
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TrackingStats {
    /// Total faces detected
    pub total_faces_detected: u64,
    /// Currently tracked faces
    pub active_faces: u32,
    /// Average detection confidence
    pub average_confidence: f32,
    /// Processing time statistics
    pub processing_times: ProcessingTimes,
}

/// Processing time breakdown
#[frb(dart_metadata=("freezed", "immutable"))]
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct ProcessingTimes {
    /// Face detection time (ms)
    pub detection_ms: f32,
    /// Landmark detection time (ms)
    pub landmark_ms: f32,
    /// Pose estimation time (ms)
    pub pose_ms: f32,
    /// Total processing time (ms)
    pub total_ms: f32,
}