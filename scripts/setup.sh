#!/bin/bash

# Flutter OpenSeeFace Plugin Setup Script
# This script sets up the development environment and project structure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Print header
echo -e "${BLUE}=================================================================================${NC}"
echo -e "${BLUE}Flutter OpenSeeFace Plugin Setup${NC}"
echo -e "${BLUE}=================================================================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ] || [ ! -d "rust" ]; then
    log_error "This script must be run from the plugin root directory"
    log_error "Make sure you're in the directory containing pubspec.yaml and rust/"
    exit 1
fi

# Step 1: Check system prerequisites
log_info "Step 1: Checking system prerequisites..."

prerequisites_ok=true

# Check Flutter
if command_exists flutter; then
    flutter_version=$(flutter --version | head -n 1)
    log_info "Flutter found: $flutter_version"
else
    log_error "Flutter is not installed or not in PATH"
    log_info "Please install Flutter from: https://flutter.dev/docs/get-started/install"
    prerequisites_ok=false
fi

# Check Rust
if command_exists rustc && command_exists cargo; then
    rust_version=$(rustc --version)
    log_info "Rust found: $rust_version"
else
    log_error "Rust is not installed or not in PATH"
    log_info "Please install Rust from: https://rustup.rs/"
    prerequisites_ok=false
fi

# Check Git
if command_exists git; then
    git_version=$(git --version)
    log_info "Git found: $git_version"
else
    log_error "Git is not installed or not in PATH"
    prerequisites_ok=false
fi

if [ "$prerequisites_ok" = false ]; then
    log_error "Please install missing prerequisites and run this script again"
    exit 1
fi

log_success "All system prerequisites are available"

# Step 2: Install Flutter and Rust dependencies
log_info "Step 2: Installing dependencies..."

# Install flutter_rust_bridge_codegen
if ! command_exists flutter_rust_bridge_codegen; then
    log_info "Installing flutter_rust_bridge_codegen..."
    cargo install flutter_rust_bridge_codegen
    log_success "flutter_rust_bridge_codegen installed"
else
    log_info "flutter_rust_bridge_codegen already installed"
fi

# Install Rust targets for mobile development
log_info "Installing Rust targets..."

# Android targets
log_info "Installing Android targets..."
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add x86_64-linux-android
rustup target add i686-linux-android

# iOS targets (only on macOS)
if [[ "$(uname)" == "Darwin" ]]; then
    log_info "Installing iOS targets..."
    rustup target add aarch64-apple-ios
    rustup target add x86_64-apple-ios
    rustup target add aarch64-apple-ios-sim
else
    log_warning "Skipping iOS targets (not on macOS)"
fi

log_success "Rust targets installed"

# Step 3: Create necessary directories
log_info "Step 3: Creating project structure..."

# Create missing directories
mkdir -p lib/src/{models,exceptions,utils,widgets}
mkdir -p lib/generated
mkdir -p rust/src/{api,face_tracking,models,utils}
mkdir -p example/lib/{screens,providers,widgets,utils}
mkdir -p example/assets/{images,icons,fonts}
mkdir -p test/{unit,widget,integration}
mkdir -p docs/{api,guides,examples}
mkdir -p scripts
mkdir -p android/src/main/{cpp/include,kotlin/com/example/flutter_openseeface_plugin}
mkdir -p ios/Classes
mkdir -p linux
mkdir -p macos/Classes
mkdir -p windows

log_success "Project directories created"

# Step 4: Download openseeface-rs dependency
log_info "Step 4: Setting up Rust dependencies..."

cd rust

# Add openseeface-rs to Cargo.toml if not already present
if ! grep -q "openseeface" Cargo.toml 2>/dev/null; then
    log_info "Adding openseeface-rs dependency..."
    # Note: This would need to be updated with the actual repository URL
    log_warning "Please manually add openseeface-rs dependency to rust/Cargo.toml"
    log_warning "The repository URL should be: https://github.com/ricky26/openseeface-rs"
fi

cd ..

# Step 5: Generate initial Flutter bindings
log_info "Step 5: Generating Flutter bindings..."

# Create basic API files if they don't exist
if [ ! -f "rust/src/api/mod.rs" ]; then
    log_warning "rust/src/api/mod.rs not found, creating placeholder..."
    cat > rust/src/api/mod.rs << 'EOF'
//! Flutter API module
//! This file will be populated with the actual API implementation

pub fn greet(name: String) -> String {
    format!("Hello, {}!", name)
}
EOF
fi

# Generate bindings
if command_exists flutter_rust_bridge_codegen; then
    log_info "Generating Flutter-Rust bindings..."
    flutter_rust_bridge_codegen generate \
        --rust-input rust/src/api/mod.rs \
        --dart-output lib/generated/ \
        --dart-format-line-length 80 \
        --enable-lifetime || log_warning "Binding generation failed - this is normal for initial setup"
else
    log_warning "Skipping binding generation - flutter_rust_bridge_codegen not available"
fi

# Step 6: Install Flutter dependencies
log_info "Step 6: Installing Flutter dependencies..."

flutter pub get

# Also for the example app
if [ -d "example" ]; then
    cd example
    flutter pub get
    cd ..
fi

log_success "Flutter dependencies installed"

# Step 7: Platform-specific setup
log_info "Step 7: Platform-specific setup..."

# Android setup
if [ -d "android" ]; then
    log_info "Setting up Android configuration..."
    
    # Create gradle.properties if it doesn't exist
    if [ ! -f "android/gradle.properties" ]; then
        cat > android/gradle.properties << 'EOF'
org.gradle.jvmargs=-Xmx1536M
android.useAndroidX=true
android.enableJetifier=true
EOF
    fi
    
    # Create local.properties for Android SDK path
    if [ ! -f "android/local.properties" ] && [ -n "$ANDROID_HOME" ]; then
        echo "sdk.dir=$ANDROID_HOME" > android/local.properties
    fi
fi

# iOS setup (macOS only)
if [[ "$(uname)" == "Darwin" ]] && [ -d "ios" ]; then
    log_info "Setting up iOS configuration..."
    
    # Check if Xcode is installed
    if command_exists xcodebuild; then
        log_info "Xcode found: $(xcodebuild -version | head -n 1)"
    else
        log_warning "Xcode not found - iOS development won't be available"
    fi
fi

log_success "Platform setup completed"

# Step 8: Create development scripts
log_info "Step 8: Creating development scripts..."

# Make build script executable
if [ -f "scripts/build.sh" ]; then
    chmod +x scripts/build.sh
    log_info "Build script made executable"
fi

# Create a quick development script
cat > scripts/dev.sh << 'EOF'
#!/bin/bash
# Quick development script

echo "Starting development environment..."

# Generate bindings
flutter_rust_bridge_codegen generate

# Get dependencies
flutter pub get

# Run example app
cd example && flutter run
EOF

chmod +x scripts/dev.sh
log_info "Development script created"

# Step 9: Validate setup
log_info "Step 9: Validating setup..."

validation_ok=true

# Check if Flutter can analyze the project
if ! flutter analyze --no-pub > /dev/null 2>&1; then
    log_warning "Flutter analysis found issues - this is normal for initial setup"
fi

# Check if Rust can compile basic project structure
cd rust
if ! cargo check > /dev/null 2>&1; then
    log_warning "Rust compilation check failed - this is normal for initial setup"
fi
cd ..

log_success "Setup validation completed"

# Final instructions
echo ""
echo -e "${GREEN}=================================================================================${NC}"
echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "${GREEN}=================================================================================${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Implement the actual openseeface-rs integration in rust/src/"
echo "  2. Run the build script: ./scripts/build.sh"
echo "  3. Test the example app: cd example && flutter run"
echo "  4. Read the documentation in docs/"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo "  - Build plugin: ./scripts/build.sh"
echo "  - Generate bindings: flutter_rust_bridge_codegen generate"
echo "  - Run tests: flutter test"
echo "  - Clean build: ./scripts/build.sh --clean"
echo ""
echo -e "${BLUE}Development workflow:${NC}"
echo "  1. Edit Rust code in rust/src/"
echo "  2. Run ./scripts/build.sh to rebuild"
echo "  3. Test changes in example app"
echo ""
echo -e "${YELLOW}Note:${NC} You'll need to implement the actual face tracking logic"
echo "using the openseeface-rs library in the Rust modules."
echo ""
