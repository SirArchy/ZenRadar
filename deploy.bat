@echo off
REM ZenRadar Deployment Script for Windows
REM This script builds the Flutter web app and deploys it to Firebase Hosting

echo 🚀 Starting ZenRadar deployment...

REM Clean and get dependencies
echo 🧹 Cleaning project and getting dependencies...
flutter clean
flutter pub get

REM Build the web app
echo 🔨 Building Flutter web app...
flutter build web --release

REM Check if build was successful
if %ERRORLEVEL% EQU 0 (
    echo ✅ Build successful!
    
    REM Deploy to Firebase
    echo 🌐 Deploying to Firebase...
    firebase deploy --only hosting,functions
    
    if %ERRORLEVEL% EQU 0 (
        echo 🎉 Deployment successful!
        echo Your app should be available at your Firebase Hosting URL
    ) else (
        echo ❌ Deployment failed!
        exit /b 1
    )
) else (
    echo ❌ Build failed!
    exit /b 1
)
