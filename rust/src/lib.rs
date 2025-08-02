//! Flutter OpenSeeFace Plugin - Rust Implementation
//! 
//! This library provides face tracking capabilities for Flutter applications
//! using the openseeface-rs library for high-performance face detection and landmark tracking.

pub mod api;
pub mod face_tracking;
pub mod models;
pub mod utils;
pub mod error;

use flutter_rust_bridge::frb;
use lazy_static::lazy_static;
use std::sync::Arc;
use tokio::sync::RwLock;

use crate::face_tracking::tracker::FaceTracker;
use crate::error::PluginError;

// Global tracker instance
lazy_static! {
    static ref GLOBAL_TRACKER: Arc<RwLock<Option<FaceTracker>>> = Arc::new(RwLock::new(None));
}

/// Initialize the native library
#[frb(init)]
pub fn init_app() {
    // Initialize logging
    #[cfg(target_os = "android")]
    android_logger::init_once(
        android_logger::Config::default()
            .with_max_level(log::LevelFilter::Info)
            .with_tag("FlutterOpenSeeFace")
    );

    #[cfg(not(target_os = "android"))]
    env_logger::init();

    log::info!("Flutter OpenSeeFace Plugin initialized");
}

/// Create and initialize the Rust async runtime for handling async operations
pub fn create_runtime() -> tokio::runtime::Runtime {
    tokio::runtime::Runtime::new().expect("Failed to create Tokio runtime")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_init() {
        init_app();
        // Basic initialization test
        assert!(true);
    }
}
