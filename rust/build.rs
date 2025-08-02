//! Build script for Flutter OpenSeeFace Plugin
//! 
//! This build script handles platform-specific configuration and
//! flutter_rust_bridge code generation.

use std::env;
use std::path::PathBuf;

fn main() {
    // Generate flutter_rust_bridge bindings
    flutter_rust_bridge_codegen::generate_all();

    // Platform-specific configuration
    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap();
    let target_arch = env::var("CARGO_CFG_TARGET_ARCH").unwrap();
    
    println!("cargo:rerun-if-changed=src/");
    println!("cargo:rerun-if-changed=build.rs");
    
    match target_os.as_str() {
        "android" => configure_android(),
        "ios" => configure_ios(),
        "windows" => configure_windows(),
        "macos" => configure_macos(),
        "linux" => configure_linux(),
        _ => println!("cargo:warning=Unknown target OS: {}", target_os),
    }
    
    println!("cargo:rustc-env=TARGET_ARCH={}", target_arch);
    println!("cargo:rustc-env=TARGET_OS={}", target_os);
}

fn configure_android() {
    println!("cargo:rustc-link-lib=log");
    println!("cargo:rustc-link-lib=android");
    
    // Add Android-specific search paths if needed
    if let Ok(ndk_home) = env::var("ANDROID_NDK_HOME") {
        let ndk_path = PathBuf::from(ndk_home);
        println!("cargo:rustc-link-search=native={}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib", ndk_path.display());
    }
    
    // Configure for different Android architectures
    let target = env::var("TARGET").unwrap();
    match target.as_str() {
        "aarch64-linux-android" => {
            println!("cargo:rustc-link-search=native=/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android");
        }
        "armv7-linux-androideabi" => {
            println!("cargo:rustc-link-search=native=/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi");
        }
        "x86_64-linux-android" => {
            println!("cargo:rustc-link-search=native=/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/x86_64-linux-android");
        }
        "i686-linux-android" => {
            println!("cargo:rustc-link-search=native=/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/i686-linux-android");
        }
        _ => {}
    }
    
    println!("cargo:warning=Building for Android target: {}", env::var("TARGET").unwrap());
}

fn configure_ios() {
    println!("cargo:rustc-link-lib=framework=Foundation");
    println!("cargo:rustc-link-lib=framework=CoreGraphics");
    println!("cargo:rustc-link-lib=framework=CoreMedia");
    println!("cargo:rustc-link-lib=framework=AVFoundation");
    
    // iOS-specific compiler flags
    println!("cargo:rustc-link-arg=-Wl,-ios_version_min,11.0");
    
    let target = env::var("TARGET").unwrap();
    match target.as_str() {
        "aarch64-apple-ios" => {
            println!("cargo:warning=Building for iOS ARM64 (device)");
        }
        "x86_64-apple-ios" => {
            println!("cargo:warning=Building for iOS x86_64 (simulator)");
        }
        "aarch64-apple-ios-sim" => {
            println!("cargo:warning=Building for iOS ARM64 (simulator)");
        }
        _ => {}
    }
}

fn configure_windows() {
    println!("cargo:rustc-link-lib=user32");
    println!("cargo:rustc-link-lib=kernel32");
    println!("cargo:rustc-link-lib=gdi32");
    
    // Windows-specific configuration
    if env::var("CARGO_CFG_TARGET_ARCH").unwrap() == "x86_64" {
        println!("cargo:warning=Building for Windows x64");
    } else {
        println!("cargo:warning=Building for Windows x86");
    }
    
    // Add Windows SDK paths if available
    if let Ok(windows_sdk) = env::var("WindowsSdkDir") {
        println!("cargo:rustc-link-search=native={}/Lib", windows_sdk);
    }
}

fn configure_macos() {
    println!("cargo:rustc-link-lib=framework=Foundation");
    println!("cargo:rustc-link-lib=framework=CoreGraphics");
    println!("cargo:rustc-link-lib=framework=CoreMedia");
    println!("cargo:rustc-link-lib=framework=AVFoundation");
    println!("cargo:rustc-link-lib=framework=Cocoa");
    
    // macOS deployment target
    println!("cargo:rustc-link-arg=-Wl,-macosx_version_min,10.15");
    
    let target_arch = env::var("CARGO_CFG_TARGET_ARCH").unwrap();
    match target_arch.as_str() {
        "aarch64" => println!("cargo:warning=Building for macOS ARM64 (Apple Silicon)"),
        "x86_64" => println!("cargo:warning=Building for macOS x86_64 (Intel)"),
        _ => println!("cargo:warning=Building for macOS {}", target_arch),
    }
}

fn configure_linux() {
    println!("cargo:rustc-link-lib=X11");
    println!("cargo:rustc-link-lib=pthread");
    println!("cargo:rustc-link-lib=dl");
    
    // Try to find system libraries
    pkg_config::Config::new()
        .atleast_version("1.0")
        .probe("x11")
        .unwrap_or_else(|_| {
            println!("cargo:warning=Could not find X11 via pkg-config, using system default");
            pkg_config::Library::default()
        });
    
    let target_arch = env::var("CARGO_CFG_TARGET_ARCH").unwrap();
    println!("cargo:warning=Building for Linux {}", target_arch);
}

// Helper function to check if we're in a CI environment
fn _is_ci() -> bool {
    env::var("CI").is_ok() || 
    env::var("CONTINUOUS_INTEGRATION").is_ok() ||
    env::var("GITHUB_ACTIONS").is_ok() ||
    env::var("GITLAB_CI").is_ok()
}

// Helper function to get build optimization level
fn _get_opt_level() -> String {
    env::var("OPT_LEVEL").unwrap_or_else(|_| "0".to_string())
}

// Print build information
fn _print_build_info() {
    println!("cargo:warning=Flutter OpenSeeFace Plugin - Rust Build");
    println!("cargo:warning=Target: {}", env::var("TARGET").unwrap_or_else(|_| "unknown".to_string()));
    println!("cargo:warning=Profile: {}", env::var("PROFILE").unwrap_or_else(|_| "unknown".to_string()));
    println!("cargo:warning=Opt Level: {}", _get_opt_level());
    
    if _is_ci() {
        println!("cargo:warning=Building in CI environment");
    }
}