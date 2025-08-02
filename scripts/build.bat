@echo off
REM Flutter OpenSeeFace Plugin Build Script for Windows
REM This script builds the Rust library and generates Flutter bindings

setlocal enabledelayedexpansion

REM Configuration
set BUILD_MODE=release
set CLEAN=false
set VERBOSE=false
set GENERATE_BINDINGS=true

REM Colors (limited in cmd)
set RED=[91m
set GREEN=[92m
set YELLOW=[93m
set BLUE=[94m
set NC=[0m

REM Parse command line arguments
:parse_args
if "%~1"=="" goto :args_done
if "%~1"=="--debug" (
    set BUILD_MODE=debug
    shift
    goto :parse_args
)
if "%~1"=="--release" (
    set BUILD_MODE=release
    shift
    goto :parse_args
)
if "%~1"=="--clean" (
    set CLEAN=true
    shift
    goto :parse_args
)
if "%~1"=="--verbose" (
    set VERBOSE=true
    shift
    goto :parse_args
)
if "%~1"=="--no-bindings" (
    set GENERATE_BINDINGS=false
    shift
    goto :parse_args
)
if "%~1"=="--help" (
    echo Usage: %~nx0 [OPTIONS]
    echo.
    echo Options:
    echo   --debug          Build in debug mode ^(default: release^)
    echo   --release        Build in release mode
    echo   --clean          Clean build artifacts before building
    echo   --verbose        Enable verbose output
    echo   --no-bindings    Skip binding generation
    echo   --help           Show this help message
    echo.
    echo Examples:
    echo   %~nx0                          # Build for current platform in release mode
    echo   %~nx0 --debug                  # Build in debug mode
    echo   %~nx0 --clean                  # Clean and build
    exit /b 0
)
echo Unknown option: %~1
exit /b 1

:args_done

REM Print header
echo %BLUE%=================================================================================%NC%
echo %BLUE%Flutter OpenSeeFace Plugin Build Script (Windows)%NC%
echo %BLUE%=================================================================================%NC%
echo.

REM Function to check if command exists
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo %RED%[ERROR]%NC% Flutter is not installed or not in PATH
    exit /b 1
)

where cargo >nul 2>&1
if %errorlevel% neq 0 (
    echo %RED%[ERROR]%NC% Rust/Cargo is not installed or not in PATH
    exit /b 1
)

where flutter_rust_bridge_codegen >nul 2>&1
if %errorlevel% neq 0 (
    echo %RED%[ERROR]%NC% flutter_rust_bridge_codegen is not installed
    echo %BLUE%[INFO]%NC% Install with: cargo install flutter_rust_bridge_codegen
    exit /b 1
)

echo %GREEN%[SUCCESS]%NC% All prerequisites are available

REM Clean if requested
if "%CLEAN%"=="true" (
    echo %BLUE%[INFO]%NC% Cleaning build artifacts...
    
    if exist "rust\target" (
        rmdir /s /q "rust\target"
        echo %BLUE%[INFO]%NC% Cleaned Rust target directory
    )
    
    if exist "build" (
        rmdir /s /q "build"
        echo %BLUE%[INFO]%NC% Cleaned Flutter build directory
    )
    
    if exist "lib\generated" (
        del /q "lib\generated\*"
        echo %BLUE%[INFO]%NC% Cleaned generated bindings
    )
    
    echo %GREEN%[SUCCESS]%NC% Build artifacts cleaned
)

REM Install Rust targets
echo %BLUE%[INFO]%NC% Installing Rust targets...
rustup target add x86_64-pc-windows-msvc
rustup target add i686-pc-windows-msvc
rustup target add aarch64-pc-windows-msvc
echo %GREEN%[SUCCESS]%NC% Rust targets installed

REM Generate bindings
if "%GENERATE_BINDINGS%"=="true" (
    echo %BLUE%[INFO]%NC% Generating Flutter bindings...
    
    if not exist "lib\generated" mkdir "lib\generated"
    
    set BRIDGE_CMD=flutter_rust_bridge_codegen generate --rust-input rust\src\api\mod.rs --dart-output lib\generated\ --dart-format-line-length 80 --enable-lifetime
    if "%VERBOSE%"=="true" set BRIDGE_CMD=%BRIDGE_CMD% --verbose
    
    %BRIDGE_CMD%
    if %errorlevel% neq 0 (
        echo %RED%[ERROR]%NC% Failed to generate bindings
        exit /b 1
    )
    
    echo %GREEN%[SUCCESS]%NC% Flutter bindings generated
)

REM Get Flutter dependencies
echo %BLUE%[INFO]%NC% Getting Flutter dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo %RED%[ERROR]%NC% Failed to get Flutter dependencies
    exit /b 1
)
echo %GREEN%[SUCCESS]%NC% Flutter dependencies updated

REM Build Rust library
echo %BLUE%[INFO]%NC% Building Rust library in %BUILD_MODE% mode...

cd rust

set BUILD_FLAGS=
if "%BUILD_MODE%"=="release" set BUILD_FLAGS=--release
if "%VERBOSE%"=="true" set BUILD_FLAGS=%BUILD_FLAGS% --verbose

echo %BLUE%[INFO]%NC% Building for Windows x64...
cargo build %BUILD_FLAGS% --target x86_64-pc-windows-msvc
if %errorlevel% neq 0 (
    echo %RED%[ERROR]%NC% Failed to build for x64
    cd ..
    exit /b 1
)

echo %BLUE%[INFO]%NC% Building for Windows x86...
cargo build %BUILD_FLAGS% --target i686-pc-windows-msvc
if %errorlevel% neq 0 (
    echo %RED%[ERROR]%NC% Failed to build for x86
    cd ..
    exit /b 1
)

cd ..
echo %GREEN%[SUCCESS]%NC% Rust library built successfully

REM Run tests if debug build
if "%BUILD_MODE%"=="debug" (
    echo %BLUE%[INFO]%NC% Running tests...
    
    echo %BLUE%[INFO]%NC% Running Rust tests...
    cd rust
    cargo test %VERBOSE:true=--verbose%
    if %errorlevel% neq 0 (
        echo %RED%[ERROR]%NC% Rust tests failed
        cd ..
        exit /b 1
    )
    cd ..
    
    echo %BLUE%[INFO]%NC% Running Dart tests...
    flutter test
    if %errorlevel% neq 0 (
        echo %RED%[ERROR]%NC% Dart tests failed
        exit /b 1
    )
    
    echo %GREEN%[SUCCESS]%NC% All tests passed
)

echo.
echo %GREEN%[SUCCESS]%NC% Build completed successfully
echo.
echo %BLUE%Next steps:%NC%
echo   1. Run the example: cd example ^&^& flutter run
echo   2. Run tests: flutter test
echo   3. Check the generated API in lib\generated\
echo.