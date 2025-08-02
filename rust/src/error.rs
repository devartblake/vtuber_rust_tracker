//! Face tracking implementation using openseeface-rs
//!
//! This module provides the main FaceTracker struct that handles face detection,
//! landmark tracking, and pose estimation using the openseeface-rs library.

use crate::api::TrackerConfig;
use crate::models::*;
use crate::error::PluginError;
use openseeface::{Tracker as OpenSeeFaceTracker, TrackerConfig as OSFConfig};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use tokio::sync::RwLock;
use tokio::time::{Duration, Instant};
use flutter_rust_bridge::StreamSink;

/// Main face tracker implementation
pub struct FaceTracker {
    /// OpenSeeFace tracker instance
    tracker: Arc<RwLock<OpenSeeFaceTracker>>,
    /// Tracker configuration
    config: TrackerConfig,
    /// Whether tracking is currently active
    is_running: AtomicBool,
    /// Total frames processed
    frames_processed: AtomicU64,
    /// Frame processing statistics
    stats: Arc<RwLock<TrackingStats>>,
    /// Last processing time
    last_process_time: Arc<RwLock<Instant>>,
}

impl FaceTracker {
    /// Create a new face tracker with the given configuration
    pub fn new(config: TrackerConfig) -> Result<Self, PluginError> {
        log::info!("Creating face tracker with config: {:?}", config);

        // Convert our config to OpenSeeFace config
        let osf_config = OSFConfig {
            model_type: match config.model_type {
                ModelType::RetinaFace => openseeface::ModelType::RetinaFace,
                ModelType::MTCNN => openseeface::ModelType::MTCNN,
            },
            confidence_threshold: config.confidence_threshold,
            max_faces: config.max_faces as usize,
            enable_landmarks: config.enable_landmarks,
            ..Default::default()
        };

        // Initialize the OpenSeeFace tracker
        let tracker = OpenSeeFaceTracker::new(osf_config)
            .map_err(|e| PluginError::TrackerInitialization(e.to_string()))?;

        let stats = TrackingStats {
            total_faces_detected: 0,
            active_faces: 0,
            average_confidence: 0.0,
            processing_times: ProcessingTimes {
                detection_ms: 0.0,
                landmark_ms: 0.0,
                pose_ms: 0.0,
                total_ms: 0.0,
            },
        };

        Ok(Self {
            tracker: Arc::new(RwLock::new(tracker)),
            config,
            is_running: AtomicBool::new(false),
            frames_processed: AtomicU64::new(0),
            stats: Arc::new(RwLock::new(stats)),
            last_process_time: Arc::new(RwLock::new(Instant::now())),
        })
    }

    /// Process a single camera frame
    pub async fn process_frame(&self, frame: CameraFrame) -> Result<Vec<Face>, PluginError> {
        let start_time = Instant::now();

        // Convert camera frame to image format expected by openseeface
        let image = self.convert_frame_to_image(&frame)?;

        // Process the frame
        let mut tracker = self.tracker.write().await;
        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_millis() as i64;

        tracker.detect(&image, timestamp)
            .map_err(|e| PluginError::ProcessingError(e.to_string()))?;

        // Convert detected faces to our format
        let faces = self.convert_detected_faces(&*tracker, timestamp).await?;

        // Update statistics
        let processing_time = start_time.elapsed().as_millis() as f32;
        self.update_stats(&faces, processing_time).await;

        // Update frame counter
        self.frames_processed.fetch_add(1, Ordering::Relaxed);

        Ok(faces)
    }

    /// Start continuous face tracking stream
    pub async fn start_stream(&self) -> Result<StreamSink<Vec<Face>>, PluginError> {
        log::info!("Starting face tracking stream");
        
        self.is_running.store(true, Ordering::Relaxed);
        
        // Create a stream sink for sending face data to Flutter
        let (sink, stream) = flutter_rust_bridge::StreamSink::new();
        
        // Note: In a real implementation, you would set up a camera capture loop here
        // For now, we return the sink that can be used to manually send frames
        
        Ok(sink)
    }

    /// Stop face tracking
    pub async fn stop(&mut self) -> Result<(), PluginError> {
        log::info!("Stopping face tracking");
        self.is_running.store(false, Ordering::Relaxed);
        Ok(())
    }

    /// Get current tracker status
    pub async fn get_status(&self) -> TrackerStatus {
        let stats = self.stats.read().await;
        let frames_processed = self.frames_processed.load(Ordering::Relaxed);
        
        // Calculate average FPS
        let last_time = *self.last_process_time.read().await;
        let elapsed = last_time.elapsed().as_secs_f32();
        let average_fps = if elapsed > 0.0 {
            frames_processed as f32 / elapsed
        } else {
            0.0
        };

        TrackerStatus {
            is_initialized: true,
            is_running: self.is_running.load(Ordering::Relaxed),
            frames_processed,
            average_fps,
            last_error: None, // TODO: Implement error tracking
        }
    }

    /// Convert camera frame to image format
    fn convert_frame_to_image(&self, frame: &CameraFrame) -> Result<image::RgbImage, PluginError> {
        match frame.format {
            ImageFormat::RGB => {
                image::RgbImage::from_raw(frame.width, frame.height, frame.image_data.clone())
                    .ok_or_else(|| PluginError::ImageConversion("Failed to create RGB image".to_string()))
            }
            ImageFormat::RGBA => {
                // Convert RGBA to RGB
                let rgba_image = image::RgbaImage::from_raw(frame.width, frame.height, frame.image_data.clone())
                    .ok_or_else(|| PluginError::ImageConversion("Failed to create RGBA image".to_string()))?;
                
                let rgb_data: Vec<u8> = rgba_image
                    .pixels()
                    .flat_map(|p| [p[0], p[1], p[2]])
                    .collect();
                
                image::RgbImage::from_raw(frame.width, frame.height, rgb_data)
                    .ok_or_else(|| PluginError::ImageConversion("Failed to convert RGBA to RGB".to_string()))
            }
            ImageFormat::YUV420 => {
                // Convert YUV420 to RGB (simplified conversion)
                let rgb_data = self.yuv420_to_rgb(&frame.image_data, frame.width, frame.height)?;
                image::RgbImage::from_raw(frame.width, frame.height, rgb_data)
                    .ok_or_else(|| PluginError::ImageConversion("Failed to create RGB from YUV420".to_string()))
            }
            _ => Err(PluginError::UnsupportedImageFormat(format!("{:?}", frame.format)))
        }
    }

    /// Convert YUV420 to RGB (basic conversion)
    fn yuv420_to_rgb(&self, yuv_data: &[u8], width: u32, height: u32) -> Result<Vec<u8>, PluginError> {
        let y_size = (width * height) as usize;
        let uv_size = y_size / 4;
        
        if yuv_data.len() < y_size + 2 * uv_size {
            return Err(PluginError::ImageConversion("Invalid YUV420 data size".to_string()));
        }

        let mut rgb_data = Vec::with_capacity(y_size * 3);
        
        for y in 0..height {
            for x in 0..width {
                let y_index = (y * width + x) as usize;
                let uv_index = ((y / 2) * (width / 2) + (x / 2)) as usize;
                
                let y_val = yuv_data[y_index] as f32;
                let u_val = yuv_data[y_size + uv_index] as f32 - 128.0;
                let v_val = yuv_data[y_size + uv_size + uv_index] as f32 - 128.0;
                
                // YUV to RGB conversion
                let r = (y_val + 1.402 * v_val).clamp(0.0, 255.0) as u8;
                let g = (y_val - 0.344 * u_val - 0.714 * v_val).clamp(0.0, 255.0) as u8;
                let b = (y_val + 1.772 * u_val).clamp(0.0, 255.0) as u8;
                
                rgb_data.extend_from_slice(&[r, g, b]);
            }
        }
        
        Ok(rgb_data)
    }

    /// Convert detected faces from OpenSeeFace format to our format
    async fn convert_detected_faces(
        &self,
        tracker: &OpenSeeFaceTracker,
        timestamp: i64,
    ) -> Result<Vec<Face>, PluginError> {
        let mut faces = Vec::new();
        
        for (id, face) in tracker.faces().iter().enumerate() {
            let bounding_box = BoundingBox {
                x: face.bbox.x,
                y: face.bbox.y,
                width: face.bbox.width,
                height: face.bbox.height,
            };

            let landmarks = if self.config.enable_landmarks && !face.landmarks.is_empty() {
                let points: Vec<Point2D> = face.landmarks
                    .iter()
                    .map(|p| Point2D { x: p.x, y: p.y })
                    .collect();
                
                let confidences = vec![face.confidence; points.len()];
                
                Some(FacialLandmarks { points, confidences })
            } else {
                None
            };

            let pose = if self.config.enable_pose_estimation {
                Some(HeadPose {
                    pitch: face.pose.pitch,
                    yaw: face.pose.yaw,
                    roll: face.pose.roll,
                    translation: Point3D {
                        x: face.pose.translation.x,
                        y: face.pose.translation.y,
                        z: face.pose.translation.z,
                    },
                    confidence: face.pose.confidence,
                })
            } else {
                None
            };

            let gaze = if self.config.enable_gaze_tracking {
                // Placeholder - implement actual gaze tracking
                Some(EyeGaze {
                    left_eye_direction: Point3D { x: 0.0, y: 0.0, z: 1.0 },
                    right_eye_direction: Point3D { x: 0.0, y: 0.0, z: 1.0 },
                    combined_direction: Point3D { x: 0.0, y: 0.0, z: 1.0 },
                    confidence: 0.5,
                })
            } else {
                None
            };

            faces.push(Face {
                id: id as u32,
                bounding_box,
                confidence: face.confidence,
                landmarks,
                pose,
                gaze,
                timestamp,
            });
        }

        Ok(faces)
    }

    /// Update tracking statistics
    async fn update_stats(&self, faces: &[Face], processing_time: f32) {
        let mut stats = self.stats.write().await;
        
        stats.total_faces_detected += faces.len() as u64;
        stats.active_faces = faces.len() as u32;
        
        if !faces.is_empty() {
            let total_confidence: f32 = faces.iter().map(|f| f.confidence).sum();
            stats.average_confidence = total_confidence / faces.len() as f32;
        }
        
        stats.processing_times.total_ms = processing_time;
        // TODO: Break down processing time by component
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_face_tracker_creation() {
        let config = TrackerConfig::default();
        let tracker = FaceTracker::new(config);
        assert!(tracker.is_ok());
    }

    #[tokio::test]
    async fn test_tracker_status() {
        let config = TrackerConfig::default();
        let tracker = FaceTracker::new(config).unwrap();
        
        let status = tracker.get_status().await;
        assert!(status.is_initialized);
        assert!(!status.is_running);
    }
}
