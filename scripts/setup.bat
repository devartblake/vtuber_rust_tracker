@echo off
REM Flutter OpenSeeFace Plugin Setup Script for Windows
REM This script sets up the development environment and project structure

setlocal enabledelayedexpansion

REM Colors (limited in cmd)
set RED=[91m
set GREEN=[92m
set YELLOW=[93m
set BLUE=[94m
set NC=[0m

REM Print header
echo %BLUE%=================================================================================%NC%
echo %BLUE%Flutter OpenSeeFace Plugin Setup (Windows)%NC%
echo %BLUE%=================================================================================%NC%
echo.

REM Check if we're in the right directory
if not exist "pubspec.yaml" (
    echo %RED%[ERROR]%NC% This script must be run from the plugin root directory
    echo %RED%[ERROR]%NC% Make sure you're in the directory containing pubspec.yaml
    exit /b 1
)

if not exist "rust" (
    echo %RED%[ERROR]%NC% This script must be run from the plugin root directory
    echo %RED%[ERROR]%NC% Make sure you're in the directory containing the rust\ folder
    exit /b 1
)

REM Step 1: Check system prerequisites
echo %BLUE%[INFO]%NC% Step 1: Checking system prerequisites...

set prerequisites_ok=true

REM Check Flutter
where flutter >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('flutter --version 2^>nul ^| findstr /r "Flutter"') do echo %BLUE%[INFO]%NC% Flutter found: %%i
) else (
    echo %RED%[ERROR]%NC% Flutter is not installed or not in PATH
    echo %BLUE%[INFO]%NC% Please install Flutter from: https://flutter.dev/docs/get-started/install
    set prerequisites_ok=false
)

REM Check Rust
where rustc >nul 2>&1
if %errorlevel% equ 0 (
    where cargo >nul 2>&1
    if !errorlevel! equ 0 (
        for /f "tokens=*" %%i in ('rustc --version 2^>nul') do echo %BLUE%[INFO]%NC% Rust found: %%i
    ) else (
        echo %RED%[ERROR]%NC% Cargo is not installed or not in PATH
        set prerequisites_ok=false
    )
) else (
    echo %RED%[ERROR]%NC% Rust is not installed or not in PATH
    echo %BLUE%[INFO]%NC% Please install Rust from: https://rustup.rs/
    set prerequisites_ok=false
)

REM Check Git
where git >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('git --version 2^>nul') do echo %BLUE%[INFO]%NC% Git found: %%i
) else (
    echo %RED%[ERROR]%NC% Git is not installed or not in PATH
    set prerequisites_ok=false
)

if "%prerequisites_ok%"=="false" (
    echo %RED%[ERROR]%NC% Please install missing prerequisites and run this script again
    exit /b 1
)

echo %GREEN%[SUCCESS]%NC% All system prerequisites are available

REM Step 2: Install Flutter and Rust dependencies
echo %BLUE%[INFO]%NC% Step 2: Installing dependencies...

REM Install flutter_rust_bridge_codegen
where flutter_rust_bridge_codegen >nul 2>&1
if %errorlevel% neq 0 (
    echo %BLUE%[INFO]%NC% Installing flutter_rust_bridge_codegen...
    cargo install flutter_rust_bridge_codegen
    if !errorlevel! neq 0 (
        echo %RED%[ERROR]%NC% Failed to install flutter_rust_bridge_codegen
        exit /b 1
    )
    echo %GREEN%[SUCCESS]%NC% flutter_rust_bridge_codegen installed
) else (
    echo %BLUE%[INFO]%NC% flutter_rust_bridge_codegen already installed
)

REM Install Rust targets
echo %BLUE%[INFO]%NC% Installing Rust targets...

echo %BLUE%[INFO]%NC% Installing Windows targets...
rustup target add x86_64-pc-windows-msvc
rustup target add i686-pc-windows-msvc
rustup target add aarch64-pc-windows-msvc

REM Android targets (if Android development is desired)
echo %BLUE%[INFO]%NC% Installing Android targets...
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add x86_64-linux-android
rustup target add i686-linux-android

echo %GREEN%[SUCCESS]%NC% Rust targets installed

REM Step 3: Create necessary directories
echo %BLUE%[INFO]%NC% Step 3: Creating project structure...

REM Create missing directories
if not exist "lib\src\models" mkdir "lib\src\models"
if not exist "lib\src\exceptions" mkdir "lib\src\exceptions"
if not exist "lib\src\utils" mkdir "lib\src\utils"
if not exist "lib\src\widgets" mkdir "lib\src\widgets"
if not exist "lib\generated" mkdir "lib\generated"
if not exist "rust\src\api" mkdir "rust\src\api"
if not exist "rust\src\face_tracking" mkdir "rust\src\face_tracking"
if not exist "rust\src\models" mkdir "rust\src\models"
if not exist "rust\src\utils" mkdir "rust\src\utils"
if not exist "example\lib\screens" mkdir "example\lib\screens"
if not exist "example\lib\providers" mkdir "example\lib\providers"
if not exist "example\lib\widgets" mkdir "example\lib\widgets"
if not exist "example\lib\utils" mkdir "example\lib\utils"
if not exist "example\assets\images" mkdir "example\assets\images"
if not exist "example\assets\icons" mkdir "example\assets\icons"
if not exist "example\assets\fonts" mkdir "example\assets\fonts"
if not exist "test\unit" mkdir "test\unit"
if not exist "test\widget" mkdir "test\widget"
if not exist "test\integration" mkdir "test\integration"
if not exist "docs\api" mkdir "docs\api"
if not exist "docs\guides" mkdir "docs\guides"
if not exist "docs\examples" mkdir "docs\examples"
if not exist "scripts" mkdir "scripts"
if not exist "android\src\main\cpp\include" mkdir "android\src\main\cpp\include"
if not exist "android\src\main\kotlin\com\example\flutter_openseeface_plugin" mkdir "android\src\main\kotlin\com\example\flutter_openseeface_plugin"
if not exist "ios\Classes" mkdir "ios\Classes"
if not exist "linux" mkdir "linux"
if not exist "macos\Classes" mkdir "macos\Classes"
if not exist "windows" mkdir "windows"

echo %GREEN%[SUCCESS]%NC% Project directories created

REM Step 4: Setup Rust dependencies
echo %BLUE%[INFO]%NC% Step 4: Setting up Rust dependencies...

cd rust

REM Check if openseeface dependency is in Cargo.toml
findstr /c:"openseeface" Cargo.toml >nul 2>&1
if %errorlevel% neq 0 (
    echo %BLUE%[INFO]%NC% Adding openseeface-rs dependency...
    echo %YELLOW%[WARNING]%NC% Please manually add openseeface-rs dependency to rust\Cargo.toml
    echo %YELLOW%[WARNING]%NC% The repository URL should be: https://github.com/ricky26/openseeface-rs
)

cd ..

REM Step 5: Generate initial Flutter bindings
echo %BLUE%[INFO]%NC% Step 5: Generating Flutter bindings...

REM Create basic API files if they don't exist
if not exist "rust\src\api\mod.rs" (
    echo %YELLOW%[WARNING]%NC% rust\src\api\mod.rs not found, creating placeholder...
    (
        echo //! Flutter API module
        echo //! This file will be populated with the actual API implementation
        echo.
        echo pub fn greet^(name: String^) -^> String {
        echo     format!^("Hello, {}!", name^)
        echo }
    ) > "rust\src\api\mod.rs"
)

REM Generate bindings
where flutter_rust_bridge_codegen >nul 2>&1
if %errorlevel% equ 0 (
    echo %BLUE%[INFO]%NC% Generating Flutter-Rust bindings...
    flutter_rust_bridge_codegen generate --rust-input rust\src\api\mod.rs --dart-output lib\generated\ --dart-format-line-length 80 --enable-lifetime 2>nul
    if !errorlevel! neq 0 (
        echo %YELLOW%[WARNING]%NC% Binding generation failed - this is normal for initial setup
    )
) else (
    echo %YELLOW%[WARNING]%NC% Skipping binding generation - flutter_rust_bridge_codegen not available
)

REM Step 6: Install Flutter dependencies
echo %BLUE%[INFO]%NC% Step 6: Installing Flutter dependencies...

flutter pub get
if %errorlevel% neq 0 (
    echo %RED%[ERROR]%NC% Failed to get Flutter dependencies
    exit /b 1
)

REM Also for the example app
if exist "example" (
    cd example
    flutter pub get
    if !errorlevel! neq 0 (
        echo %YELLOW%[WARNING]%NC% Failed to get example app dependencies
    )
    cd ..
)

echo %GREEN%[SUCCESS]%NC% Flutter dependencies installed

REM Step 7: Platform-specific setup
echo %BLUE%[INFO]%NC% Step 7: Platform-specific setup...

REM Windows setup
if exist "android" (
    echo %BLUE%[INFO]%NC% Setting up Android configuration...
    
    REM Create gradle.properties if it doesn't exist
    if not exist "android\gradle.properties" (
        (
            echo org.gradle.jvmargs=-Xmx1536M
            echo android.useAndroidX=true
            echo android.enableJetifier=true
        ) > "android\gradle.properties"
    )
    
    REM Create local.properties for Android SDK path
    if not exist "android\local.properties" (
        if defined ANDROID_HOME (
            echo sdk.dir=%ANDROID_HOME% > "android\local.properties"
        )
    )
)

echo %GREEN%[SUCCESS]%NC% Platform setup completed

REM Step 8: Create development scripts
echo %BLUE%[INFO]%NC% Step 8: Creating development scripts...

REM Create a quick development script
if not exist "scripts\dev.bat" (
    (
        echo @echo off
        echo REM Quick development script
        echo.
        echo echo Starting development environment...
        echo.
        echo REM Generate bindings
        echo flutter_rust_bridge_codegen generate
        echo.
        echo REM Get dependencies
        echo flutter pub get
        echo.
        echo REM Run example app
        echo cd example ^&^& flutter run
    ) > "scripts\dev.bat"
)

echo %BLUE%[INFO]%NC% Development script created

REM Step 9: Validate setup
echo %BLUE%[INFO]%NC% Step 9: Validating setup...

REM Check if Flutter can analyze the project
flutter analyze --no-pub >nul 2>&1
if %errorlevel% neq 0 (
    echo %YELLOW%[WARNING]%NC% Flutter analysis found issues - this is normal for initial setup
)

REM Check if Rust can compile basic project structure
cd rust
cargo check >nul 2>&1
if %errorlevel% neq 0 (
    echo %YELLOW%[WARNING]%NC% Rust compilation check failed - this is normal for initial setup
)
cd ..

echo %GREEN%[SUCCESS]%NC% Setup validation completed

REM Final instructions
echo.
echo %GREEN%=================================================================================%NC%
echo %GREEN%Setup completed successfully!%NC%
echo %GREEN%=================================================================================%NC%
echo.
echo %BLUE%Next steps:%NC%
echo   1. Implement the actual openseeface-rs integration in rust\src\
echo   2. Run the build script: scripts\build.bat
echo   3. Test the example app: cd example ^&^& flutter run
echo   4. Read the documentation in docs\
echo.
echo %BLUE%Useful commands:%NC%
echo   - Build plugin: scripts\build.bat
echo   - Generate bindings: flutter_rust_bridge_codegen generate
echo   - Run tests: flutter test
echo   - Clean build: scripts\build.bat --clean
echo.
echo %BLUE%Development workflow:%NC%
echo   1. Edit Rust code in rust\src\
echo   2. Run scripts\build.bat to rebuild
echo   3. Test changes in example app
echo.
echo %YELLOW%Note:%NC% You'll need to implement the actual face tracking logic
echo using the openseeface-rs library in the Rust modules.
echo.