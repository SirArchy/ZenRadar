# ZenRadar - Premium Matcha Stock Monitoring

ZenRadar is a comprehensive Flutter application that monitors matcha tea stock availability across 10+ premium Japanese and international tea websites. The app features real-time background monitoring, intelligent notifications, and a sophisticated cloud-based crawler service to ensure you never miss when your favorite matcha comes back in stock.

## ✨ Features

🍵 **Comprehensive Stock Monitoring**
- Monitors 10+ premium matcha vendors globally
- Cloud-based crawler service with specialized parsers for each site
- Real-time product availability tracking with variant support
- Handles complex e-commerce structures (Shopify, custom platforms)

📱 **Intelligent Notifications**
- Firebase Cloud Messaging for reliable push notifications
- Smart notification grouping and deduplication
- Customizable active hours to respect your schedule
- Favorite products system for priority alerts

⚙️ **Advanced User Controls**
- Granular site-specific monitoring controls
- Flexible check frequency configuration (1-24 hours)
- Filter by price ranges and product categories
- Comprehensive settings with test functionality

📊 **Advanced Analytics**
- Local SQLite database with full stock history
- Product availability trends and statistics
- Last check timestamps for all monitored sites
- Automatic data cleanup and optimization

🔄 **Background Service**
- Persistent background monitoring using flutter_background_service
- Continues monitoring even when app is closed
- Intelligent error handling and retry logic
- Battery-optimized crawling schedules

## 🌐 Monitored Websites

### Japanese Premium Vendors
- **Tokichi Global**: https://global.tokichi.jp/collections/matcha
- **Marukyu-Koyamaen**: https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha
- **Ippodo Tea**: https://global.ippodo-tea.co.jp/collections/matcha
- **Yoshien**: https://yoshien.com/collections/matcha
- **Horiishichimeien**: https://horiishichimeien.co.jp/collections/matcha

### International Specialty Vendors
- **Matcha Karu**: https://matchakaru.com/collections/matcha
- **Sho-Cha**: https://sho-cha.com/collections/matcha
- **Sazentea**: https://sazentea.com/collections/matcha
- **Enjoy Emerican**: https://enjoyemeri.com/collections/matcha
- **Poppatea (German)**: https://poppatea.com/de-de/collections/all-teas

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK** (3.0+): Latest stable version
- **Android Studio** or **VS Code** with Flutter extensions
- **Android device/emulator** for testing (API level 21+)
- **Google Cloud Account** (for cloud crawler deployment)
- **Firebase Project** (for notifications and data sync)

### Quick Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd ZenRadar
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**:
   - Create a new Firebase project at https://console.firebase.google.com
   - Add an Android app to your project
   - Download `google-services.json` and place it in `android/app/`
   - Enable Firestore and Cloud Messaging in Firebase console

4. **Set up Cloud Crawler** (Optional for development):
   ```bash
   cd cloud-run-crawler
   npm install
   npm test  # Test crawler functionality locally
   ```

5. **Run the app**:
   ```bash
   flutter run
   ```

### Production Deployment

#### Mobile App Release
```bash
# Build release APK
flutter build apk --release

# Build App Bundle for Google Play
flutter build appbundle --release
```

#### Cloud Crawler Deployment
```bash
cd cloud-run-crawler
./deploy.sh  # Deploys to Google Cloud Run
```

### Environment Configuration

Create a `.env` file in the project root:
```env
FIREBASE_PROJECT_ID=your-project-id
CLOUD_RUN_URL=https://your-crawler-service.run.app
CRAWLER_API_KEY=your-api-key
```

## 🏗️ Architecture

ZenRadar uses a sophisticated multi-tier architecture combining local Flutter components with cloud-based services:

### Flutter Mobile App (Android)
```
lib/
├── main.dart                    # App entry point with Firebase initialization
├── models/                      # Data models and entities
│   ├── matcha_product.dart
│   ├── site_config.dart
│   └── notification_data.dart
├── services/                    # Business logic and integrations
│   ├── background_service.dart   # Flutter background service
│   ├── firebase_service.dart    # FCM and Firestore integration
│   ├── database_service.dart    # Local SQLite operations
│   ├── notification_service.dart # Local notification handling
│   └── crawler_coordinator.dart # Coordinates with cloud crawler
├── screens/                     # UI screens and navigation
│   ├── home_screen.dart         # Product listings and status
│   ├── settings_screen.dart     # User preferences
│   └── favorites_screen.dart    # Favorite products management
└── widgets/                     # Reusable UI components
    ├── product_card.dart
    ├── site_toggle.dart
    └── notification_settings.dart
```

### Cloud Crawler Service (Google Cloud Run)
```
cloud-run-crawler/
├── src/
│   ├── crawler-service.js       # Main orchestration service
│   ├── crawlers/                # Specialized site crawlers
│   │   ├── tokichi-crawler.js
│   │   ├── marukyu-crawler.js
│   │   ├── ippodo-crawler.js
│   │   ├── poppatea-crawler.js  # German Shopify site
│   │   └── [8+ more specialized crawlers]
│   ├── utils/
│   │   ├── price-parser.js      # Multi-currency price handling
│   │   ├── stock-detector.js    # Stock status detection
│   │   └── variant-processor.js # Product variant handling
│   └── firebase-integration.js  # Firestore data sync
├── Dockerfile                   # Container configuration
└── deploy.sh                   # Cloud deployment script
```

### Firebase Backend
- **Firestore**: Product data, stock history, user preferences
- **Cloud Messaging**: Push notification delivery
- **Authentication**: Optional user account management
- **Cloud Functions**: Notification triggers and data processing

## 🔧 Technical Stack

### Mobile Development
- **Flutter SDK**: Cross-platform mobile framework
- **Dart**: Programming language
- **flutter_background_service**: Persistent background execution
- **flutter_local_notifications**: Local notification system
- **firebase_core & firebase_messaging**: Firebase integration
- **sqflite**: Local SQLite database
- **shared_preferences**: User settings persistence
- **http**: HTTP client for API communication

### Cloud Infrastructure
- **Google Cloud Run**: Serverless crawler hosting
- **Node.js**: Server-side JavaScript runtime
- **Puppeteer**: Headless browser for complex sites
- **Cheerio**: Server-side HTML parsing
- **Firebase Admin SDK**: Backend Firebase integration

### Data Management
- **SQLite**: Local product and history storage
- **Firestore**: Cloud data synchronization
- **Shared Preferences**: User setting persistence

## ⚙️ How It Works

### 1. **Intelligent Crawling System**
The cloud-based crawler service uses specialized parsers for each monitored website:
- **Site-Specific Adapters**: Each vendor has a custom crawler that understands their unique page structure
- **Anti-Detection**: Randomized user agents, request delays, and respectful crawling practices
- **Multi-Language Support**: Handles sites in Japanese, English, and German
- **Variant Processing**: Extracts product variants (sizes, grades, packaging options)

### 2. **Smart Stock Detection**
Advanced algorithms detect stock status across different e-commerce platforms:
- **Text Pattern Recognition**: Recognizes "Out of Stock", "Sold Out", "Temporarily Unavailable" in multiple languages
- **Button State Analysis**: Detects disabled "Add to Cart" buttons
- **Price Availability**: Monitors price display patterns to infer availability
- **Inventory Counters**: Tracks quantity indicators when available

### 3. **Real-Time Synchronization**
- **Cloud-First Architecture**: Crawler runs in the cloud, mobile app syncs data
- **Incremental Updates**: Only changed products trigger notifications
- **Conflict Resolution**: Handles simultaneous updates from multiple sources
- **Offline Resilience**: App functions with cached data when offline

### 4. **Notification Intelligence**
- **Favorite Priority**: Favorite products get immediate notifications
- **Deduplication**: Prevents spam from rapid stock changes
- **Time-Based Filtering**: Respects user-defined active hours
- **Summary Grouping**: Combines multiple stock changes into summary notifications

### 5. **Data Management**
- **Local SQLite**: Fast local queries and offline functionality
- **Cloud Sync**: Firestore provides cross-device synchronization
- **Automatic Cleanup**: Removes old stock history to optimize storage
- **Privacy First**: All personal data stays on your device

## 📱 User Experience

### Core Workflows

1. **First Time Setup**:
   - Grant notification permissions
   - Select preferred sites to monitor
   - Configure check frequency and active hours
   - Test notification delivery

2. **Daily Usage**:
   - View current stock status of all monitored products
   - Mark products as favorites for priority alerts
   - Receive notifications when stock becomes available
   - Browse stock history and availability trends

3. **Advanced Configuration**:
   - Fine-tune monitoring settings per site
   - Set price range filters
   - Configure notification grouping preferences
   - Monitor crawler service health

### Settings & Controls

- **Site Management**: Enable/disable individual tea vendors
- **Timing Controls**: Set check intervals (1-24 hours) and active hours
- **Notification Preferences**: Customize alert types and frequency
- **Data Management**: View storage usage and clear history
- **Testing Tools**: Test notifications and crawler connectivity

## 🔒 Privacy & Security

- **Local-First Design**: All personal preferences and history stored locally
- **No Personal Data Collection**: We don't collect or store any personal information
- **Direct Website Access**: Crawler makes requests directly to tea vendors
- **Firebase Security**: Anonymous authentication with Firestore security rules
- **Opt-in Cloud Sync**: Users can choose to sync data across devices

## 🛠️ Troubleshooting

### Background Service Issues
- **Android Battery Optimization**: Disable battery optimization for ZenRadar
- **Auto-Start Management**: Enable auto-start on Xiaomi/Huawei devices
- **Background App Refresh**: Ensure background execution is allowed
- **Notification Permissions**: Verify all notification permissions are granted

### Crawler Service Problems
- **Network Connectivity**: Check internet connection and firewall settings
- **Site Accessibility**: Some vendors may be temporarily unavailable
- **Rate Limiting**: Crawler respects site limits; delays are normal
- **Firebase Connection**: Verify Firebase project configuration

### Notification Troubleshooting
- **Test Notifications**: Use built-in test function in Settings
- **Do Not Disturb**: Check DND and notification channel settings
- **Firebase Token**: Token may need refresh if notifications stop
- **Active Hours**: Verify current time falls within configured active hours

### Data Sync Issues
- **Firestore Rules**: Check Firebase security rules are properly configured
- **Network Errors**: Sync requires stable internet connection
- **Storage Limits**: Firestore has daily usage limits for free tier
- **Conflict Resolution**: Manual refresh may be needed for data conflicts

## 🧪 Development & Testing

### Running Tests
```bash
# Flutter unit tests
flutter test

# Cloud crawler tests
cd cloud-run-crawler && npm test

# Integration tests
flutter drive --target=test_driver/app.dart
```

### Local Development Setup
```bash
# Start Firebase emulator
firebase emulators:start

# Run crawler locally
cd cloud-run-crawler && npm start

# Flutter hot reload
flutter run --debug
```

### Debugging Tools
- **Flutter Inspector**: Visual widget debugging
- **Firebase Console**: Monitor Firestore data and FCM delivery
- **Cloud Logging**: View crawler service logs
- **Network Inspector**: Debug HTTP requests and responses

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Workflow
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

### Areas for Contribution
- **New Site Crawlers**: Add support for additional matcha vendors
- **UI/UX Improvements**: Enhance mobile app interface
- **Performance Optimization**: Improve crawler efficiency and app responsiveness
- **Internationalization**: Add support for more languages
- **Testing**: Expand test coverage for both mobile and cloud components

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

ZenRadar is designed for personal use and educational purposes. Please:
- Respect the terms of service of monitored websites
- Use reasonable check frequencies to avoid overloading servers
- Be mindful of crawler impact on small tea vendor websites
- Consider purchasing from vendors you monitor to support their business

## 📧 Support

For questions, bug reports, or feature requests:
- Open an issue on GitHub
- Check existing documentation and troubleshooting guides
- Review Firebase and Flutter official documentation for technical issues

---

**Built with ❤️ for the matcha community**
