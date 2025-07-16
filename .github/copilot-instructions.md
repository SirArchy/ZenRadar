# ZenRadar - Matcha Stock Monitoring App

<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

## Project Overview
ZenRadar is a Flutter Android app that monitors matcha stock availability on multiple websites and sends push notifications when items come back in stock.

## Architecture Guidelines
- Use clean architecture with separate layers for data, domain, and presentation
- Implement background services using flutter_background_service for Android
- Use flutter_local_notifications for push notifications
- Store user preferences and stock state using shared_preferences or sqflite
- Implement HTTP requests with the http package and HTML parsing with html package

## Key Features
1. **Background Crawling**: Monitor matcha sites (Tokichi, Marukyu-Koyamaen, Ippodo) for stock changes
2. **User Settings**: Allow users to configure check frequency and active hours
3. **Push Notifications**: Send local notifications when stock becomes available
4. **State Management**: Track previous stock states to avoid duplicate notifications

## Target Sites
- https://global.tokichi.jp/collections/matcha
- https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha
- https://global.ippodo-tea.co.jp/collections/matcha

## Dependencies to Include
- flutter_background_service: For background task execution
- flutter_local_notifications: For push notifications
- http: For web requests
- html: For HTML parsing
- shared_preferences: For user settings storage
- sqflite: For local database (stock state tracking)

## Code Style
- Follow Dart/Flutter conventions
- Use meaningful variable and function names
- Add comprehensive error handling for network requests
- Implement proper null safety
- Add logging for debugging background tasks
