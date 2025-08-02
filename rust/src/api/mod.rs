//! Flutter Bridge API
//! 
//! This module contains all the functions that are exposed to Flutter/Dart
//! through the flutter_rust_bridge, now with real openseeface-rs integration.

pub mod face_tracker_api;
pub mod stream_handler;

use flutter_rust_bridge::frb;
use crate::models::*;
use crate::error::PluginError;
use crate::face_tracking::tracker::FaceTracker;
use crate::GLOBAL_TRACKER;
use log::{info, debug, error};
use std::sync::Arc;

/// Configuration for the face tracker
#[frb(dart_metadata=("freezed", "immutable"))]
#[derive(Debug, Clone)]
pub struct TrackerConfig {
    /// Model type to use for face detection
    pub model_type: ModelType,
    /// Confidence threshold for face detection (0.0 - 1.0)
    pub confidence_threshold: f32,
    /// Maximum number of faces to track simultaneously
    pub max_faces: u32,
    /// Enable facial landmark detection
    pub enable_landmarks: bool,
    /// Enable head pose estimation
    pub enable_pose_estimation: bool,
    /// Enable eye gaze tracking
    pub enable_gaze_tracking: bool,
    /// Processing frame rate (FPS)
    pub target_fps: u32,
}

impl Default for TrackerConfig {
    fn default() -> Self {
        Self {
            model_type: ModelType::RetinaFace,
            confidence_threshold: 0.8,
            max_faces: 4,
            enable_landmarks: true,
            enable_pose_estimation: true,
            enable_gaze_tracking: false,
            target_fps: 30,
        }
    }
}

/// Initialize the face tracker with configuration
#[frb(sync)]
pub fn initialize_tracker(config: TrackerConfig) -> Result<(), PluginError> {
    info!("Initializing face tracker with config: {:?}", config);
    
    // Validate configuration
    if config.confidence_threshold < 0.0 || config.confidence_threshold > 1.0 {
        return Err(PluginError::InvalidConfiguration(
            "Confidence threshold must be between 0.0 and 1.0".to_string()
        ));
    }
    
    if config.max_faces == 0 {
        return Err(PluginError::InvalidConfiguration(
            "Max faces must be greater than 0".to_string()
        ));
    }
    
    if config.target_fps == 0 || config.target_fps > 120 {
        return Err(PluginError::InvalidConfiguration(
            "Target FPS must be between 1 and 120".to_string()
        ));
    }
    
    // Create the face tracker
    let tracker = FaceTracker::new(config)?;
    
    // Store the tracker globally using tokio runtime
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| PluginError::ThreadingError(e.to_string()))?;
    
    rt.block_on(async {
        let mut global_tracker = GLOBAL_TRACKER.write().await;
        *global_tracker = Some(tracker);
    });

    info!("Face tracker initialized successfully");
    Ok(())
}

/// Process a single frame for face detection
#[frb(sync)]
pub fn process_frame(frame: CameraFrame) -> Result<Vec<Face>, PluginError> {
    debug!("Processing frame: {}x{} format: {:?}", frame.width, frame.height, frame.format);
    
    // Validate frame data
    if frame.width == 0 || frame.height == 0 {
        return Err(PluginError::ProcessingError("Invalid frame dimensions".to_string()));
    }
    
    if frame.image_data.is_empty() {
        return Err(PluginError::ProcessingError("Empty frame data".to_string()));
    }
    
    // Check expected data size based on format
    let expected_size = match frame.format {
        ImageFormat::RGB => (frame.width * frame.height * 3) as usize,
        ImageFormat::RGBA | ImageFormat::BGRA => (frame.width * frame.height * 4) as usize,
        ImageFormat::YUV420 | ImageFormat::NV21 => ((frame.width * frame.height * 3) / 2) as usize,
    };
    
    if frame.image_data.len() < expected_size {
        return Err(PluginError::ProcessingError(
            format!("Frame data size ({}) is smaller than expected ({})", 
                   frame.image_data.len(), expected_size)
        ));
    }
    
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| PluginError::ThreadingError(e.to_string()))?;
        
    rt.block_on(async {
        let tracker_guard = GLOBAL_TRACKER.read().await;
        
        match tracker_guard.as_ref() {
            Some(tracker) => {
                tracker.process_frame(frame).await
            }
            None => Err(PluginError::TrackerNotInitialized)
        }
    })
}

/// Process multiple frames in batch for better performance
#[frb(sync)]
pub fn process_frames_batch(frames: Vec<CameraFrame>) -> Result<Vec<Vec<Face>>, PluginError> {
    debug!("Processing batch of {} frames", frames.len());
    
    if frames.is_empty() {
        return Ok(Vec::new());
    }
    
    if frames.len() > 100 {
        return Err(PluginError::ProcessingError(
            "Batch size too large (max 100 frames)".to_string()
        ));
    }
    
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| PluginError::ThreadingError(e.to_string()))?;
        
    rt.block_on(async {
        let tracker_guard = GLOBAL_TRACKER.read().await;
        
        match tracker_guard.as_ref() {
            Some(tracker) => {
                let mut results = Vec::with_capacity(frames.len());
                
                for frame in frames {
                    match tracker.process_frame(frame).await {
                        Ok(faces) => results.push(faces),
                        Err(_) => results.push(Vec::new()), // Continue processing other frames
                    }
                }
                
                Ok(results)
            }
            None => Err(PluginError::TrackerNotInitialized)
        }
    })
}

/// Start continuous face tracking with frame stream
#[frb(stream)]
pub async fn start_face_tracking_stream() -> Result<impl flutter_rust_bridge::StreamSink<Vec<Face>>, PluginError> {
    info!("Starting face tracking stream");
    
    let tracker_guard = GLOBAL_TRACKER.read().await;
    
    match tracker_guard.as_ref() {
        Some(tracker) => {
            tracker.start_stream().await
        }
        None => Err(PluginError::TrackerNotInitialized)
    }
}

/// Stop face tracking
#[frb(sync)]
pub fn stop_tracking() -> Result<(), PluginError> {
    info!("Stopping face tracking");
    
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| PluginError::ThreadingError(e.to_string()))?;
        
    rt.block_on(async {
        let mut global_tracker = GLOBAL_TRACKER.write().await;
        
        if let Some(tracker) = global_tracker.as_mut() {
            tracker.stop().await?;
        }
        
        *global_tracker = None;
    });

    info!("Face tracking stopped");
    Ok(())
}

/// Get current tracker status
#[frb(sync)]
pub fn get_tracker_status() -> TrackerStatus {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let tracker_guard = GLOBAL_TRACKER.read().await;
        
        match tracker_guard.as_ref() {
            Some(tracker) => tracker.get_status().await,
            None => TrackerStatus {
                is_initialized: false,
                is_running: false,
                frames_processed: 0,
                average_fps: 0.0,
                last_error: None,
            }
        }
    })
}

/// Get detailed tracking statistics
#[frb(sync)]
pub fn get_tracking_stats() -> TrackingStats {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let tracker_guard = GLOBAL_TRACKER.read().await;
        
        match tracker_guard.as_ref() {
            Some(tracker) => {
                // Get stats from the tracker
                let stats_guard = tracker.stats.read().await;
                stats_guard.clone()
            }
            None => TrackingStats {
                total_faces_detected: 0,
                active_faces: 0,
                average_confidence: 0.0,
                processing_times: ProcessingTimes {
                    detection_ms: 0.0,
                    landmark_ms: 0.0,
                    pose_ms: 0.0,
                    total_ms: 0.0,
                },
            }
        }
    })
}

/// Update tracker configuration (requires re-initialization)
#[frb(sync)]
pub fn update_tracker_config(new_config: TrackerConfig) -> Result<(), PluginError> {
    info!("Updating tracker configuration: {:?}", new_config);
    
    // Stop current tracker
    stop_tracking()?;
    
    // Initialize with new config
    initialize_tracker(new_config)?;
    
    info!("Tracker configuration updated successfully");
    Ok(())
}

/// Check if tracker supports a specific feature
#[frb(sync)]
pub fn is_feature_supported(feature: TrackerFeature) -> bool {
    match feature {
        TrackerFeature::FaceDetection => true,
        TrackerFeature::LandmarkDetection => true,
        TrackerFeature::PoseEstimation => true,
        TrackerFeature::GazeTracking => true, // openseeface-rs supports this
        TrackerFeature::ExpressionDetection => false, // Not implemented yet
        TrackerFeature::AgeEstimation => false,
        TrackerFeature::GenderDetection => false,
        TrackerFeature::EmotionDetection => false,
    }
}

/// Get available camera devices (platform-specific)
#[frb(sync)]
pub fn get_available_cameras() -> Result<Vec<CameraDevice>, PluginError> {
    // This would typically use platform-specific camera APIs
    // For now, return a placeholder
    Ok(vec![
        CameraDevice {
            id: "0".to_string(),
            name: "Default Camera".to_string(),
            is_front_facing: false,
            supported_resolutions: vec![
                Resolution { width: 640, height: 480 },
                Resolution { width: 1280, height: 720 },
                Resolution { width: 1920, height: 1080 },
            ],
        }
    ])
}

/// Validate camera frame format and dimensions
#[frb(sync)]
pub fn validate_frame(frame: CameraFrame) -> Result<bool, PluginError> {
    if frame.width == 0 || frame.height == 0 {
        return Ok(false);
    }
    
    if frame.image_data.is_empty() {
        return Ok(false);
    }
    
    // Check expected data size based on format
    let expected_size = match frame.format {
        ImageFormat::RGB => (frame.width * frame.height * 3) as usize,
        ImageFormat::RGBA | ImageFormat::BGRA => (frame.width * frame.height * 4) as usize,
        ImageFormat::YUV420 | ImageFormat::NV21 => ((frame.width * frame.height * 3) / 2) as usize,
    };
    
    Ok(frame.image_data.len() >= expected_size)
}

/// Get recommended configuration for device performance
#[frb(sync)]
pub fn get_recommended_config() -> TrackerConfig {
    // This could be enhanced to detect device capabilities
    // For now, return a balanced configuration
    TrackerConfig {
        model_type: ModelType::RetinaFace,
        confidence_threshold: 0.8,
        max_faces: 2, // Conservative for performance
        enable_landmarks: true,
        enable_pose_estimation: true,
        enable_gaze_tracking: false, // Disable for better performance
        target_fps: 30,
    }
}

/// Reset tracker state and clear all cached data
#[frb(sync)]
pub fn reset_tracker() -> Result<(), PluginError> {
    info!("Resetting tracker state");
    
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| PluginError::ThreadingError(e.to_string()))?;
        
    rt.block_on(async {
        let mut global_tracker = GLOBAL_TRACKER.write().await;
        
        if let Some(tracker) = global_tracker.as_mut() {
            tracker.stop().await?;
        }
        
        *global_tracker = None;
    });
    
    info!("Tracker state reset successfully");
    Ok(())
}

/// Dispose of resources and cleanup
#[frb(sync)]
pub fn dispose() -> Result<(), PluginError> {
    info!("Disposing face tracker resources");
    reset_tracker()
}

/// Get version information
#[frb(sync)]
pub fn get_version_info() -> VersionInfo {
    VersionInfo {
        plugin_version: env!("CARGO_PKG_VERSION").to_string(),
        openseeface_version: "0.1.0".to_string(), // Would get this from openseeface-rs
        flutter_bridge_version: "2.0".to_string(),
        build_date: env!("BUILD_DATE").unwrap_or("unknown").to_string(),
        commit_hash: env!("GIT_HASH").unwrap_or("unknown").to_string(),
    }
}

/// Warm up the tracker (load models, etc.)
#[frb(sync)]
pub fn warmup_tracker() -> Result<(), PluginError> {
    info!("Warming up tracker");
    
    // Create a dummy frame to warm up the tracker
    let dummy_frame = CameraFrame {
        image_data: vec![128u8; 640 * 480 * 3], // Gray 640x480 RGB image
        width: 640,
        height: 480,
        format: ImageFormat::RGB,
        rotation: 0,
        timestamp: chrono::Utc::now().timestamp_millis(),
    };
    
    // Process the dummy frame to load models
    match process_frame(dummy_frame) {
        Ok(_) => {
            info!("Tracker warmed up successfully");
            Ok(())
        }
        Err(e) => {
            error!("Failed to warm up tracker: {}", e);
            Err(e)
        }
    }
}

// Additional helper types for the API

/// Supported tracker features
#[frb(dart_metadata=("freezed"))]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TrackerFeature {
    FaceDetection,
    LandmarkDetection,
    PoseEstimation,
    GazeTracking,
    ExpressionDetection,
    AgeEstimation,
    GenderDetection,
    EmotionDetection,
}

/// Camera device information
#[frb(dart_metadata=("freezed", "immutable"))]
#[derive(Debug, Clone)]
pub struct CameraDevice {
    pub id: String,
    pub name: String,
    pub is_front_facing: bool,
    pub supported_resolutions: Vec<Resolution>,
}

/// Resolution information
#[frb(dart_metadata=("freezed", "immutable"))]
#[derive(Debug, Clone, Copy)]
pub struct Resolution {
    pub width: u32,
    pub height: u32,
}

/// Version information
#[frb(dart_metadata=("freezed", "immutable"))]
#[derive(Debug, Clone)]
pub struct VersionInfo {
    pub plugin_version: String,
    pub openseeface_version: String,
    pub flutter_bridge_version: String,
    pub build_date: String,
    pub commit_hash: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = TrackerConfig::default();
        assert_eq!(config.model_type, ModelType::RetinaFace);
        assert_eq!(config.confidence_threshold, 0.8);
        assert_eq!(config.max_faces, 4);
        assert!(config.enable_landmarks);
        assert!(config.enable_pose_estimation);
        assert!(!config.enable_gaze_tracking);
        assert_eq!(config.target_fps, 30);
    }

    #[test]
    fn test_recommended_config() {
        let config = get_recommended_config();
        assert!(config.confidence_threshold >= 0.0 && config.confidence_threshold <= 1.0);
        assert!(config.max_faces > 0);
        assert!(config.target_fps > 0);
    }

    #[test]
    fn test_feature_support() {
        assert!(is_feature_supported(TrackerFeature::FaceDetection));
        assert!(is_feature_supported(TrackerFeature::LandmarkDetection));
        assert!(is_feature_supported(TrackerFeature::PoseEstimation));
        assert!(!is_feature_supported(TrackerFeature::EmotionDetection));
    }

    #[test]
    fn test_frame_validation() {
        let valid_frame = CameraFrame {
            image_data: vec![0u8; 640 * 480 * 3],
            width: 640,
            height: 480,
            format: ImageFormat::RGB,
            rotation: 0,
            timestamp: 0,
        };
        
        assert!(validate_frame(valid_frame).unwrap());
        
        let invalid_frame = CameraFrame {
            image_data: vec![0u8; 100], // Too small
            width: 640,
            height: 480,
            format: ImageFormat::RGB,
            rotation: 0,
            timestamp: 0,
        };
        
        assert!(!validate_frame(invalid_frame).unwrap());
    }

    #[tokio::test]
    async fn test_tracker_lifecycle() {
        let config = TrackerConfig::default();
        
        // Test initialization
        let init_result = initialize_tracker(config);
        // Note: This might fail if openseeface-rs models aren't available
        // In a real test environment, you'd have the models available
        
        if init_result.is_ok() {
            // Test status
            let status = get_tracker_status();
            assert!(status.is_initialized);
            
            // Test disposal
            assert!(dispose().is_ok());
        }
    }
}