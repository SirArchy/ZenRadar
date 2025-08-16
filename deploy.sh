#!/bin/bash

# ZenRadar Deployment Script
# This script builds the Flutter web app and deploys it to Firebase Hosting

echo "🚀 Starting ZenRadar deployment..."

# Clean and get dependencies
echo "🧹 Cleaning project and getting dependencies..."
flutter clean
flutter pub get

# Build the web app
echo "🔨 Building Flutter web app..."
flutter build web --release

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Deploy to Firebase
    echo "🌐 Deploying to Firebase..."
    firebase deploy --only hosting,functions
    
    if [ $? -eq 0 ]; then
        echo "🎉 Deployment successful!"
        echo "Your app should be available at your Firebase Hosting URL"
    else
        echo "❌ Deployment failed!"
        exit 1
    fi
else
    echo "❌ Build failed!"
    exit 1
fi
