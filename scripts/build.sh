#!/bin/bash

# Flutter OpenSeeFace Plugin Build Script
# This script builds the Rust library and generates Flutter bindings

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BUILD_MODE="release"
PLATFORMS=()
CLEAN=false
VERBOSE=false
GENERATE_BINDINGS=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            BUILD_MODE="debug"
            shift
            ;;
        --release)
            BUILD_MODE="release"
            shift
            ;;
        --platform)
            PLATFORMS+=("$2")
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --no-bindings)
            GENERATE_BINDINGS=false
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --debug          Build in debug mode (default: release)"
            echo "  --release        Build in release mode"
            echo "  --platform NAME  Build for specific platform (android, ios, windows, macos, linux)"
            echo "  --clean          Clean build artifacts before building"
            echo "  --verbose        Enable verbose output"
            echo "  --no-bindings    Skip binding generation"
            echo "  --help           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Build for current platform in release mode"
            echo "  $0 --debug --platform android        # Build for Android in debug mode"
            echo "  $0 --clean --platform ios            # Clean and build for iOS"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Print header
echo -e "${BLUE}=================================================================================${NC}"
echo -e "${BLUE}Flutter OpenSeeFace Plugin Build Script${NC}"
echo -e "${BLUE}=================================================================================${NC}"
echo ""

# Function to print status messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command_exists flutter; then
        log_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists cargo; then
        log_error "Rust/Cargo is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists flutter_rust_bridge_codegen; then
        log_error "flutter_rust_bridge_codegen is not installed"
        log_info "Install with: cargo install flutter_rust_bridge_codegen"
        exit 1
    fi
    
    log_success "All prerequisites are available"
}

# Function to detect current platform
detect_platform() {
    case "$(uname -s)" in
        Darwin)
            echo "macos"
            ;;
        Linux)
            echo "linux"
            ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Function to clean build artifacts
clean_build() {
    log_info "Cleaning build artifacts..."
    
    # Clean Rust artifacts
    if [ -d "rust/target" ]; then
        rm -rf rust/target
        log_info "Cleaned Rust target directory"
    fi
    
    # Clean Flutter artifacts
    if [ -d "build" ]; then
        rm -rf build
        log_info "Cleaned Flutter build directory"
    fi
    
    # Clean generated bindings
    if [ -d "lib/generated" ]; then
        rm -rf lib/generated/*
        log_info "Cleaned generated bindings"
    fi
    
    log_success "Build artifacts cleaned"
}

# Function to install Rust targets
install_rust_targets() {
    log_info "Installing Rust targets..."
    
    # Android targets
    if [[ " ${PLATFORMS[@]} " =~ " android " ]] || [[ ${#PLATFORMS[@]} -eq 0 ]]; then
        rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android
        log_info "Android targets installed"
    fi
    
    # iOS targets
    if [[ " ${PLATFORMS[@]} " =~ " ios " ]] || [[ ${#PLATFORMS[@]} -eq 0 ]]; then
        if [[ "$(detect_platform)" == "macos" ]]; then
            rustup target add aarch64-apple-ios x86_64-apple-ios aarch64-apple-ios-sim
            log_info "iOS targets installed"
        else
            log_warning "Skipping iOS targets (not on macOS)"
        fi
    fi
    
    log_success "Rust targets installed"
}

# Function to generate Flutter bindings
generate_bindings() {
    if [ "$GENERATE_BINDINGS" = false ]; then
        log_info "Skipping binding generation (--no-bindings specified)"
        return
    fi
    
    log_info "Generating Flutter bindings..."
    
    # Create generated directory if it doesn't exist
    mkdir -p lib/generated
    
    # Generate bindings
    flutter_rust_bridge_codegen generate \
        --rust-input rust/src/api/mod.rs \
        --dart-output lib/generated/ \
        --dart-format-line-length 80 \
        --enable-lifetime \
        ${VERBOSE:+--verbose}
    
    log_success "Flutter bindings generated"
}

# Function to build Rust library
build_rust() {
    log_info "Building Rust library in $BUILD_MODE mode..."
    
    cd rust
    
    # Set build flags
    local build_flags=""
    if [ "$BUILD_MODE" = "release" ]; then
        build_flags="--release"
    fi
    
    if [ "$VERBOSE" = true ]; then
        build_flags="$build_flags --verbose"
    fi
    
    # Build for each platform
    if [ ${#PLATFORMS[@]} -eq 0 ]; then
        # Build for current platform
        log_info "Building for current platform: $(detect_platform)"
        cargo build $build_flags
    else
        for platform in "${PLATFORMS[@]}"; do
            log_info "Building for platform: $platform"
            
            case $platform in
                android)
                    # Build for Android targets
                    cargo build $build_flags --target aarch64-linux-android
                    cargo build $build_flags --target armv7-linux-androideabi
                    cargo build $build_flags --target x86_64-linux-android
                    cargo build $build_flags --target i686-linux-android
                    ;;
                ios)
                    if [[ "$(detect_platform)" == "macos" ]]; then
                        cargo build $build_flags --target aarch64-apple-ios
                        cargo build $build_flags --target x86_64-apple-ios
                        cargo build $build_flags --target aarch64-apple-ios-sim
                    else
                        log_warning "Cannot build iOS targets on non-macOS platform"
                    fi
                    ;;
                windows|macos|linux)
                    cargo build $build_flags
                    ;;
                *)
                    log_error "Unknown platform: $platform"
                    exit 1
                    ;;
            esac
        done
    fi
    
    cd ..
    log_success "Rust library built successfully"
}

# Function to run Flutter pub get
flutter_deps() {
    log_info "Getting Flutter dependencies..."
    flutter pub get
    log_success "Flutter dependencies updated"
}

# Function to run tests
run_tests() {
    log_info "Running tests..."
    
    # Run Rust tests
    log_info "Running Rust tests..."
    cd rust
    cargo test ${VERBOSE:+--verbose}
    cd ..
    
    # Run Dart tests
    log_info "Running Dart tests..."
    flutter test
    
    log_success "All tests passed"
}

# Main build process
main() {
    local start_time=$(date +%s)
    
    # Check prerequisites
    check_prerequisites
    
    # Clean if requested
    if [ "$CLEAN" = true ]; then
        clean_build
    fi
    
    # Install Rust targets
    install_rust_targets
    
    # Generate bindings
    generate_bindings
    
    # Get Flutter dependencies
    flutter_deps
    
    # Build Rust library
    build_rust
    
    # Run tests
    if [ "$BUILD_MODE" = "debug" ]; then
        run_tests
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    log_success "Build completed successfully in ${duration}s"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Run the example: cd example && flutter run"
    echo "  2. Run tests: flutter test"
    echo "  3. Check the generated API in lib/generated/"
    echo ""
}

# Run main function
main "$@"
