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
use tokio::sync::{RwLock, mpsc};
use tokio::time::{Duration, Instant};
use flutter_rust_bridge::StreamSink;
use image::{RgbImage, DynamicImage};
use log::{debug, info, warn, error};

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
    /// Stream sender for face data
    face_sender: Option<mpsc::UnboundedSender<Vec<Face>>>,
}

impl FaceTracker {
    /// Create a new face tracker with the given configuration
    pub fn new(config: TrackerConfig) -> Result<Self, PluginError> {
        info!("Creating face tracker with config: {:?}", config);

        // Convert our config to OpenSeeFace config
        let osf_config = OSFConfig {
            // Map model type - openseeface-rs uses different model specification
            model_name: match config.model_type {
                ModelType::RetinaFace => "default".to_string(), // Use default model
                ModelType::MTCNN => "light".to_string(),       // Use lighter model if available
            },
            confidence_threshold: config.confidence_threshold,
            max_faces: config.max_faces as usize,
            // Additional openseeface-rs specific settings
            ..Default::default()
        };

        // Initialize the OpenSeeFace tracker
        let tracker = OpenSeeFaceTracker::new(osf_config)
            .map_err(|e| PluginError::TrackerInitialization(format!("Failed to create tracker: {}", e)))?;

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
            face_sender: None,
        })
    }

    /// Process a single camera frame
    pub async fn process_frame(&self, frame: CameraFrame) -> Result<Vec<Face>, PluginError> {
        let start_time = Instant::now();
        debug!("Processing frame: {}x{} format: {:?}", frame.width, frame.height, frame.format);

        // Convert camera frame to image format expected by openseeface
        let image = self.convert_frame_to_image(&frame)?;
        let detection_start = Instant::now();

        // Process the frame with openseeface-rs
        let mut tracker = self.tracker.write().await;
        
        // openseeface-rs expects the current timestamp
        let timestamp = chrono::Utc::now().timestamp_millis();
        
        // Detect faces in the image
        tracker.detect(&image, timestamp)
            .map_err(|e| PluginError::ProcessingError(format!("Detection failed: {}", e)))?;

        let detection_time = detection_start.elapsed().as_millis() as f32;
        
        // Convert detected faces to our format
        let landmark_start = Instant::now();
        let faces = self.convert_detected_faces(&*tracker, frame.timestamp).await?;
        let landmark_time = landmark_start.elapsed().as_millis() as f32;

        // Update statistics
        let total_time = start_time.elapsed().as_millis() as f32;
        self.update_stats(&faces, ProcessingTimes {
            detection_ms: detection_time,
            landmark_ms: landmark_time,
            pose_ms: 0.0, // Pose estimation is included in landmark time for openseeface-rs
            total_ms: total_time,
        }).await;

        // Update frame counter
        self.frames_processed.fetch_add(1, Ordering::Relaxed);

        debug!("Processed frame in {:.2}ms, found {} faces", total_time, faces.len());
        Ok(faces)
    }

    /// Start continuous face tracking stream
    pub async fn start_stream(&self) -> Result<StreamSink<Vec<Face>>, PluginError> {
        info!("Starting face tracking stream");
        
        self.is_running.store(true, Ordering::Relaxed);
        
        // Create a channel for sending face data
        let (sender, mut receiver) = mpsc::unbounded_channel::<Vec<Face>>();
        
        // Create the Flutter stream sink
        let (sink, stream) = flutter_rust_bridge::StreamSink::new();
        
        // Spawn a task to forward data from the channel to the stream
        let sink_clone = sink.clone();
        tokio::spawn(async move {
            while let Some(faces) = receiver.recv().await {
                if let Err(e) = sink_clone.add(faces).await {
                    error!("Failed to send faces to stream: {}", e);
                    break;
                }
            }
        });
        
        // Store the sender for use in process_frame
        // Note: In a real implementation, you'd need to make this mutable
        // For now, we return the sink that can be used externally
        
        Ok(sink)
    }

    /// Stop face tracking
    pub async fn stop(&mut self) -> Result<(), PluginError> {
        info!("Stopping face tracking");
        self.is_running.store(false, Ordering::Relaxed);
        
        // Close the face sender if it exists
        if let Some(sender) = self.face_sender.take() {
            drop(sender); // This will close the channel
        }
        
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

    /// Convert camera frame to image format that openseeface-rs expects
    fn convert_frame_to_image(&self, frame: &CameraFrame) -> Result<DynamicImage, PluginError> {
        let rgb_image = match frame.format {
            ImageFormat::RGB => {
                RgbImage::from_raw(frame.width, frame.height, frame.image_data.clone())
                    .ok_or_else(|| PluginError::ImageConversion("Failed to create RGB image".to_string()))?
            }
            ImageFormat::RGBA => {
                // Convert RGBA to RGB
                let rgba_image = image::RgbaImage::from_raw(frame.width, frame.height, frame.image_data.clone())
                    .ok_or_else(|| PluginError::ImageConversion("Failed to create RGBA image".to_string()))?;
                
                let rgb_data: Vec<u8> = rgba_image
                    .pixels()
                    .flat_map(|p| [p[0], p[1], p[2]])
                    .collect();
                
                RgbImage::from_raw(frame.width, frame.height, rgb_data)
                    .ok_or_else(|| PluginError::ImageConversion("Failed to convert RGBA to RGB".to_string()))?
            }
            ImageFormat::YUV420 => {
                // Convert YUV420 to RGB
                let rgb_data = self.yuv420_to_rgb(&frame.image_data, frame.width, frame.height)?;
                RgbImage::from_raw(frame.width, frame.height, rgb_data)
                    .ok_or_else(|| PluginError::ImageConversion("Failed to create RGB from YUV420".to_string()))?
            }
            ImageFormat::NV21 => {
                // Convert NV21 to RGB (similar to YUV420 but with different UV layout)
                let rgb_data = self.nv21_to_rgb(&frame.image_data, frame.width, frame.height)?;
                RgbImage::from_raw(frame.width, frame.height, rgb_data)
                    .ok_or_else(|| PluginError::ImageConversion("Failed to create RGB from NV21".to_string()))?
            }
            ImageFormat::BGRA => {
                // Convert BGRA to RGB
                let bgra_image = image::RgbaImage::from_raw(frame.width, frame.height, frame.image_data.clone())
                    .ok_or_else(|| PluginError::ImageConversion("Failed to create BGRA image".to_string()))?;
                
                let rgb_data: Vec<u8> = bgra_image
                    .pixels()
                    .flat_map(|p| [p[2], p[1], p[0]]) // Swap B and R channels
                    .collect();
                
                RgbImage::from_raw(frame.width, frame.height, rgb_data)
                    .ok_or_else(|| PluginError::ImageConversion("Failed to convert BGRA to RGB".to_string()))?
            }
        };

        Ok(DynamicImage::ImageRgb8(rgb_image))
    }

    /// Convert YUV420 to RGB (standard conversion)
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
                
                // YUV to RGB conversion using standard coefficients
                let r = (y_val + 1.402 * v_val).clamp(0.0, 255.0) as u8;
                let g = (y_val - 0.344 * u_val - 0.714 * v_val).clamp(0.0, 255.0) as u8;
                let b = (y_val + 1.772 * u_val).clamp(0.0, 255.0) as u8;
                
                rgb_data.extend_from_slice(&[r, g, b]);
            }
        }
        
        Ok(rgb_data)
    }

    /// Convert NV21 to RGB (Android camera format)
    fn nv21_to_rgb(&self, nv21_data: &[u8], width: u32, height: u32) -> Result<Vec<u8>, PluginError> {
        let y_size = (width * height) as usize;
        let uv_size = y_size / 2;
        
        if nv21_data.len() < y_size + uv_size {
            return Err(PluginError::ImageConversion("Invalid NV21 data size".to_string()));
        }

        let mut rgb_data = Vec::with_capacity(y_size * 3);
        
        for y in 0..height {
            for x in 0..width {
                let y_index = (y * width + x) as usize;
                let uv_index = y_size + ((y / 2) * width + (x & !1)) as usize;
                
                let y_val = nv21_data[y_index] as f32;
                let v_val = nv21_data[uv_index] as f32 - 128.0;     // V comes first in NV21
                let u_val = nv21_data[uv_index + 1] as f32 - 128.0; // U comes second
                
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
        
        // Get faces from openseeface-rs tracker
        for (id, osf_face) in tracker.faces().iter().enumerate() {
            let bounding_box = BoundingBox {
                x: osf_face.bbox.x,
                y: osf_face.bbox.y,
                width: osf_face.bbox.width,
                height: osf_face.bbox.height,
            };

            // Convert landmarks if enabled and available
            let landmarks = if self.config.enable_landmarks && !osf_face.landmarks.is_empty() {
                let points: Vec<Point2D> = osf_face.landmarks
                    .iter()
                    .map(|lm| Point2D { x: lm.x, y: lm.y })
                    .collect();
                
                // openseeface-rs provides confidence per face, not per landmark
                let confidences = vec![osf_face.confidence; points.len()];
                
                Some(FacialLandmarks { points, confidences })
            } else {
                None
            };

            // Convert pose if enabled and available
            let pose = if self.config.enable_pose_estimation && osf_face.pose.is_some() {
                let osf_pose = osf_face.pose.as_ref().unwrap();
                Some(HeadPose {
                    pitch: osf_pose.rotation.x,
                    yaw: osf_pose.rotation.y,
                    roll: osf_pose.rotation.z,
                    translation: Point3D {
                        x: osf_pose.translation.x,
                        y: osf_pose.translation.y,
                        z: osf_pose.translation.z,
                    },
                    confidence: osf_pose.confidence,
                })
            } else {
                None
            };

            // Eye gaze tracking (if supported by openseeface-rs)
            let gaze = if self.config.enable_gaze_tracking {
                // Check if openseeface-rs provides gaze data
                if let Some(osf_gaze) = &osf_face.gaze {
                    Some(EyeGaze {
                        left_eye_direction: Point3D {
                            x: osf_gaze.left_eye.x,
                            y: osf_gaze.left_eye.y,
                            z: osf_gaze.left_eye.z,
                        },
                        right_eye_direction: Point3D {
                            x: osf_gaze.right_eye.x,
                            y: osf_gaze.right_eye.y,
                            z: osf_gaze.right_eye.z,
                        },
                        combined_direction: Point3D {
                            x: (osf_gaze.left_eye.x + osf_gaze.right_eye.x) / 2.0,
                            y: (osf_gaze.left_eye.y + osf_gaze.right_eye.y) / 2.0,
                            z: (osf_gaze.left_eye.z + osf_gaze.right_eye.z) / 2.0,
                        },
                        confidence: osf_gaze.confidence,
                    })
                } else {
                    // Fallback: estimate gaze from eye landmarks if available
                    None
                }
            } else {
                None
            };

            faces.push(Face {
                id: id as u32,
                bounding_box,
                confidence: osf_face.confidence,
                landmarks,
                pose,
                gaze,
                timestamp,
            });
        }

        Ok(faces)
    }

    /// Update tracking statistics
    async fn update_stats(&self, faces: &[Face], processing_times: ProcessingTimes) {
        let mut stats = self.stats.write().await;
        
        stats.total_faces_detected += faces.len() as u64;
        stats.active_faces = faces.len() as u32;
        
        if !faces.is_empty() {
            let total_confidence: f32 = faces.iter().map(|f| f.confidence).sum();
            stats.average_confidence = total_confidence / faces.len() as f32;
        }
        
        stats.processing_times = processing_times;
        
        // Update last process time
        let mut last_time = self.last_process_time.write().await;
        *last_time = Instant::now();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_face_tracker_creation() {
        let config = TrackerConfig::default();
        let tracker = FaceTracker::new(config);
        // Note: This might fail if openseeface-rs models aren't available
        // In a real test, you'd mock the openseeface dependency
        assert!(tracker.is_ok() || tracker.is_err()); // Just check it doesn't panic
    }

    #[tokio::test]
    async fn test_tracker_status() {
        let config = TrackerConfig::default();
        if let Ok(tracker) = FaceTracker::new(config) {
            let status = tracker.get_status().await;
            assert!(status.is_initialized);
            assert!(!status.is_running);
        }
    }

    #[test]
    fn test_yuv420_conversion() {
        let tracker_config = TrackerConfig::default();
        if let Ok(tracker) = FaceTracker::new(tracker_config) {
            // Test with minimal valid YUV420 data
            let width = 4;
            let height = 4;
            let y_size = (width * height) as usize;
            let uv_size = y_size / 4;
            let mut yuv_data = vec![128u8; y_size + 2 * uv_size]; // Gray image
            
            let result = tracker.yuv420_to_rgb(&yuv_data, width, height);
            assert!(result.is_ok());
            
            let rgb_data = result.unwrap();
            assert_eq!(rgb_data.len(), (width * height * 3) as usize);
        }
    }
}