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
