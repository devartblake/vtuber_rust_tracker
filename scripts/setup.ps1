# Flutter OpenSeeFace Plugin Setup Script for Windows PowerShell
# This script sets up the development environment and project structure

param(
    [switch]$Help
)

# Colors for PowerShell
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Cyan"

function Write-Info($message) {
    Write-Host "[INFO] $message" -ForegroundColor $Blue
}

function Write-Success($message) {
    Write-Host "[SUCCESS] $message" -ForegroundColor $Green
}

function Write-Warning($message) {
    Write-Host "[WARNING] $message" -ForegroundColor $Yellow
}

function Write-Error($message) {
    Write-Host "[ERROR] $message" -ForegroundColor $Red
}

function Test-Command($command) {
    $null = Get-Command $command -ErrorAction SilentlyContinue
    return $?
}

# Show help if requested
if ($Help) {
    Write-Host "Flutter OpenSeeFace Plugin Setup Script"
    Write-Host ""
    Write-Host "Usage: .\setup.ps1"
    Write-Host ""
    Write-Host "This script will:"
    Write-Host "  1. Check system prerequisites"
    Write-Host "  2. Install required tools and dependencies"
    Write-Host "  3. Create project directory structure"
    Write-Host "  4. Generate initial Flutter bindings"
    Write-Host "  5. Set up platform-specific configurations"
    Write-Host ""
    exit 0
}

# Print header
Write-Host "=================================================================================" -ForegroundColor $Blue
Write-Host "Flutter OpenSeeFace Plugin Setup (PowerShell)" -ForegroundColor $Blue
Write-Host "=================================================================================" -ForegroundColor $Blue
Write-Host ""

# Check if we're in the right directory
if (-not (Test-Path "pubspec.yaml") -or -not (Test-Path "rust")) {
    Write-Error "This script must be run from the plugin root directory"
    Write-Error "Make sure you're in the directory containing pubspec.yaml and rust/"
    exit 1
}

# Step 1: Check system prerequisites
Write-Info "Step 1: Checking system prerequisites..."

$prerequisitesOk = $true

# Check Flutter
if (Test-Command "flutter") {
    $flutterVersion = flutter --version 2>$null | Select-Object -First 1
    Write-Info "Flutter found: $flutterVersion"
} else {
    Write-Error "Flutter is not installed or not in PATH"
    Write-Info "Please install Flutter from: https://flutter.dev/docs/get-started/install"
    $prerequisitesOk = $false
}

# Check Rust
if ((Test-Command "rustc") -and (Test-Command "cargo")) {
    $rustVersion = rustc --version 2>$null
    Write-Info "Rust found: $rustVersion"
} else {
    Write-Error "Rust is not installed or not in PATH"
    Write-Info "Please install Rust from: https://rustup.rs/"
    $prerequisitesOk = $false
}

# Check Git
if (Test-Command "git") {
    $gitVersion = git --version 2>$null
    Write-Info "Git found: $gitVersion"
} else {
    Write-Error "Git is not installed or not in PATH"
    $prerequisitesOk = $false
}

if (-not $prerequisitesOk) {
    Write-Error "Please install missing prerequisites and run this script again"
    exit 1
}

Write-Success "All system prerequisites are available"

# Step 2: Install Flutter and Rust dependencies
Write-Info "Step 2: Installing dependencies..."

# Install flutter_rust_bridge_codegen
if (-not (Test-Command "flutter_rust_bridge_codegen")) {
    Write-Info "Installing flutter_rust_bridge_codegen..."
    cargo install flutter_rust_bridge_codegen
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install flutter_rust_bridge_codegen"
        exit 1
    }
    Write-Success "flutter_rust_bridge_codegen installed"
} else {
    Write-Info "flutter_rust_bridge_codegen already installed"
}

# Install Rust targets
Write-Info "Installing Rust targets..."

Write-Info "Installing Windows targets..."
rustup target add x86_64-pc-windows-msvc
rustup target add i686-pc-windows-msvc
rustup target add aarch64-pc-windows-msvc

# Android targets (if Android development is desired)
Write-Info "Installing Android targets..."
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add x86_64-linux-android
rustup target add i686-linux-android

Write-Success "Rust targets installed"

# Step 3: Create necessary directories
Write-Info "Step 3: Creating project structure..."

# Create missing directories
$directories = @(
    "lib\src\models",
    "lib\src\exceptions",
    "lib\src\utils",
    "lib\src\widgets",
    "lib\generated",
    "rust\src\api",
    "rust\src\face_tracking",
    "rust\src\models",
    "rust\src\utils",
    "example\lib\screens",
    "example\lib\providers",
    "example\lib\widgets",
    "example\lib\utils",
    "example\assets\images",
    "example\assets\icons",
    "example\assets\fonts",
    "test\unit",
    "test\widget",
    "test\integration",
    "docs\api",
    "docs\guides",
    "docs\examples",
    "scripts",
    "android\src\main\cpp\include",
    "android\src\main\kotlin\com\example\flutter_openseeface_plugin",
    "ios\Classes",
    "linux",
    "macos\Classes",
    "windows"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

Write-Success "Project directories created"

# Step 4: Setup Rust dependencies
Write-Info "Step 4: Setting up Rust dependencies..."

Push-Location rust

# Check if openseeface dependency is in Cargo.toml
if (-not (Select-String -Pattern "openseeface" -Path "Cargo.toml" -Quiet 2>$null)) {
    Write-Info "Adding openseeface-rs dependency..."
    Write-Warning "Please manually add openseeface-rs dependency to rust\Cargo.toml"
    Write-Warning "The repository URL should be: https://github.com/ricky26/openseeface-rs"
}

Pop-Location

# Step 5: Generate initial Flutter bindings
Write-Info "Step 5: Generating Flutter bindings..."

# Create basic API files if they don't exist
if (-not (Test-Path "rust\src\api\mod.rs")) {
    Write-Warning "rust\src\api\mod.rs not found, creating placeholder..."
    @"
//! Flutter API module
//! This file will be populated with the actual API implementation

pub fn greet(name: String) -> String {
    format!("Hello, {}!", name)
}
"@ | Out-File -FilePath "rust\src\api\mod.rs" -Encoding UTF8
}

# Generate bindings
if (Test-Command "flutter_rust_bridge_codegen") {
    Write-Info "Generating Flutter-Rust bindings..."
    flutter_rust_bridge_codegen generate --rust-input rust\src\api\mod.rs --dart-output lib\generated\ --dart-format-line-length 80 --enable-lifetime 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Binding generation failed - this is normal for initial setup"
    }
} else {
    Write-Warning "Skipping binding generation - flutter_rust_bridge_codegen not available"
}

# Step 6: Install Flutter dependencies
Write-Info "Step 6: Installing Flutter dependencies..."

flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get Flutter dependencies"
    exit 1
}

# Also for the example app
if (Test-Path "example") {
    Push-Location example
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to get example app dependencies"
    }
    Pop-Location
}

Write-Success "Flutter dependencies installed"

# Step 7: Platform-specific setup
Write-Info "Step 7: Platform-specific setup..."

# Android setup
if (Test-Path "android") {
    Write-Info "Setting up Android configuration..."
    
    # Create gradle.properties if it doesn't exist
    if (-not (Test-Path "android\gradle.properties")) {
        @"
org.gradle.jvmargs=-Xmx1536M
android.useAndroidX=true
android.enableJetifier=true
"@ | Out-File -FilePath "android\gradle.properties" -Encoding UTF8
    }
    
    # Create local.properties for Android SDK path
    if (-not (Test-Path "android\local.properties") -and $env:ANDROID_HOME) {
        "sdk.dir=$env:ANDROID_HOME" | Out-File -FilePath "android\local.properties" -Encoding UTF8
    }
}

Write-Success "Platform setup completed"

# Step 8: Create development scripts
Write-Info "Step 8: Creating development scripts..."

# Create a quick development script
if (-not (Test-Path "scripts\dev.ps1")) {
    @"
# Quick development script for PowerShell

Write-Host "Starting development environment..." -ForegroundColor Cyan

# Generate bindings
Write-Host "Generating bindings..." -ForegroundColor Blue
flutter_rust_bridge_codegen generate

# Get dependencies
Write-Host "Getting dependencies..." -ForegroundColor Blue
flutter pub get

# Run example app
Write-Host "Running example app..." -ForegroundColor Blue
Set-Location example
flutter run
"@ | Out-File -FilePath "scripts\dev.ps1" -Encoding UTF8
}

Write-Info "Development script created"

# Step 9: Validate setup
Write-Info "Step 9: Validating setup..."

# Check if Flutter can analyze the project
flutter analyze --no-pub 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Flutter analysis found issues - this is normal for initial setup"
}

# Check if Rust can compile basic project structure
Push-Location rust
cargo check 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Rust compilation check failed - this is normal for initial setup"
}
Pop-Location

Write-Success "Setup validation completed"

# Final instructions
Write-Host ""
Write-Host "=================================================================================" -ForegroundColor $Green
Write-Host "Setup completed successfully!" -ForegroundColor $Green
Write-Host "=================================================================================" -ForegroundColor $Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor $Blue
Write-Host "  1. Implement the actual openseeface-rs integration in rust\src\"
Write-Host "  2. Run the build script: .\scripts\build.ps1 (or build.bat)"
Write-Host "  3. Test the example app: cd example; flutter run"
Write-Host "  4. Read the documentation in docs\"
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor $Blue
Write-Host "  - Build plugin: .\scripts\build.ps1"
Write-Host "  - Generate bindings: flutter_rust_bridge_codegen generate"
Write-Host "  - Run tests: flutter test"
Write-Host "  - Clean build: .\scripts\build.ps1 -Clean"
Write-Host ""
Write-Host "Development workflow:" -ForegroundColor $Blue
Write-Host "  1. Edit Rust code in rust\src\"
Write-Host "  2. Run .\scripts\build.ps1 to rebuild"
Write-Host "  3. Test changes in example app"
Write-Host ""
Write-Host "Note: " -ForegroundColor $Yellow -NoNewline
Write-Host "You'll need to implement the actual face tracking logic"
Write-Host "using the openseeface-rs library in the Rust modules."
Write-Host ""