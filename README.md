# ZenRadar - Matcha Stock Monitoring App

ZenRadar is a Flutter Android application that monitors matcha tea stock availability across multiple Japanese tea websites and sends push notifications when products come back in stock.

## Features

🍵 **Real-time Stock Monitoring**
- Monitors matcha products on Tokichi Global, Marukyu-Koyamaen, and Ippodo Tea
- Background crawling service that runs even when app is closed
- Customizable check frequency (1-24 hours)

📱 **Smart Notifications**
- Instant notifications when out-of-stock products become available
- Customizable active hours to avoid nighttime notifications
- Summary notifications for multiple stock updates

⚙️ **User-Friendly Settings**
- Enable/disable monitoring for specific sites
- Adjust check frequency based on your needs
- Test notifications to ensure they're working

📊 **Stock History Tracking**
- Local database tracks stock changes over time
- View last check times for all products
- Automatic cleanup of old history data

## Monitored Websites

- **Tokichi Global**: https://global.tokichi.jp/collections/matcha
- **Marukyu-Koyamaen**: https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha
- **Ippodo Tea**: https://global.ippodo-tea.co.jp/collections/matcha

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Android Studio or VS Code with Flutter extensions
- Android device or emulator for testing

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd ZenRadar
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Building for Release

To build a release APK:
```bash
flutter build apk --release
```

## Architecture

The app follows a clean architecture pattern with the following structure:

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   └── matcha_product.dart
├── services/                 # Business logic services
│   ├── background_service.dart
│   ├── crawler_service.dart
│   ├── database_service.dart
│   └── notification_service.dart
├── screens/                  # UI screens
│   ├── home_screen.dart
│   └── settings_screen.dart
└── widgets/                  # Reusable UI components
    └── product_card.dart
```

## Key Dependencies

- **flutter_background_service**: Background task execution
- **flutter_local_notifications**: Push notifications
- **http**: Web requests for crawling
- **html**: HTML parsing for product extraction
- **sqflite**: Local database for data persistence
- **shared_preferences**: User settings storage

## How It Works

1. **Background Service**: The app runs a persistent background service that periodically checks matcha websites based on user-configured intervals.

2. **Web Crawling**: The crawler service makes HTTP requests to each monitored website and parses the HTML to extract product information and stock status.

3. **Stock Comparison**: The app compares current stock status with previously stored data to detect when products come back in stock.

4. **Notifications**: When a stock change is detected (out-of-stock → in-stock), the notification service sends a local push notification to the user.

5. **Data Persistence**: All product information and stock history is stored locally using SQLite database.

## Configuration

### Check Frequency
Users can configure how often the background service checks for stock updates:
- Every 1, 2, 4, 6, 8, 12, or 24 hours

### Active Hours
Set specific hours when monitoring should be active to avoid notifications during sleep hours.

### Site Selection
Enable or disable monitoring for specific websites based on your preferences.

## Privacy & Data

- All data is stored locally on your device
- No personal information is collected or transmitted
- Web requests are made directly to tea websites without intermediary servers

## Troubleshooting

### Background Service Not Working
- Ensure the app has permission to run in the background
- Check that battery optimization is disabled for ZenRadar
- Verify notification permissions are granted

### No Notifications Received
- Test notifications in the Settings screen
- Check that Do Not Disturb mode is not blocking notifications
- Ensure notification permissions are granted

### Products Not Loading
- Check internet connection
- Verify that the monitored websites are accessible
- Try manual refresh in the app

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This app is for educational purposes. Please respect the terms of service of the monitored websites and use reasonable check frequencies to avoid overloading their servers.
