import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:zenradar/services/backend_service.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'services/database_service.dart';
import 'services/firestore_service.dart';
import 'services/theme_service.dart';
import 'services/battery_optimization_service.dart';
import 'services/favorite_notification_service.dart';
import 'screens/app_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize only critical services synchronously
    await _initializeCriticalServices();

    // Start the app immediately
    runApp(const ZenRadarApp());

    // Initialize remaining services in background
    _initializeBackgroundServices();
  } catch (e) {
    if (kDebugMode) {
      print('Critical initialization failed: $e');
    }
    // Still start the app, but with degraded functionality
    runApp(const ZenRadarApp());
  }
}

/// Initialize only the most critical services needed for app startup
Future<void> _initializeCriticalServices() async {
  // Firebase is needed for core functionality
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Theme service for UI rendering
  await ThemeService.instance.init();

  if (kDebugMode) {
    print('Critical services initialized');
  }
}

/// Initialize remaining services in background without blocking UI
Future<void> _initializeBackgroundServices() async {
  try {
    // Initialize Firestore service
    await FirestoreService.instance.initDatabase();

    // Initialize database service
    await DatabaseService.platformService.initDatabase();

    // Only initialize mobile-specific services on mobile platforms
    if (!kIsWeb) {
      // Initialize notification service
      await NotificationService.instance.init();

      // Small delay to ensure notification channels are created
      await Future.delayed(const Duration(milliseconds: 100));

      // Check and handle battery optimization in background
      final batteryService = BatteryOptimizationService();
      batteryService.checkAndHandleBatteryOptimization();

      // Initialize background service (server mode only)
      BackgroundServiceController.initializeService();

      // Initialize FCM and favorite notification services
      BackendService.instance.initializeFCM();
      FavoriteNotificationService.instance.initializeService();

      // Request basic permissions
      requestInitialPermissions();
    }

    if (kDebugMode) {
      print('Background services initialized');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Background service initialization failed: $e');
    }
  }
}

Future<void> requestInitialPermissions() async {
  if (kIsWeb) return; // Skip permissions on web

  // Request background app refresh permission (iOS) - but NOT notification permission
  await Permission.appTrackingTransparency.request();

  // Check and handle battery optimization
  final batteryService = BatteryOptimizationService();
  await batteryService.checkAndHandleBatteryOptimization();
}

// Legacy function for requesting all permissions (including notifications)
// This is kept for compatibility but notifications should be requested through
// NotificationService.instance.requestNotificationPermission() instead
Future<void> requestPermissions() async {
  if (kIsWeb) return; // Skip permissions on web

  // Request notification permission (deprecated - use NotificationService instead)
  await Permission.notification.isDenied.then((value) {
    if (value) {
      Permission.notification.request();
    }
  });

  await requestInitialPermissions();
}

class ZenRadarApp extends StatelessWidget {
  const ZenRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, child) {
        return MaterialApp(
          title: 'ZenRadar',
          theme: ThemeService.lightTheme,
          darkTheme: ThemeService.darkTheme,
          themeMode: ThemeService.instance.flutterThemeMode,
          home: const AppInitializer(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
