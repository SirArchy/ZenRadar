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

  // Initialize Firebase for Firestore support (server mode)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      print('Firebase initialized successfully');
    }

    // Initialize Firestore service
    await FirestoreService.instance.initDatabase();
  } catch (e) {
    if (kDebugMode) {
      print('Firebase initialization failed: $e');
      print('Continuing without Firebase - server mode will not work');
    }
  }

  // Initialize services
  await DatabaseService.platformService.initDatabase();
  await ThemeService.instance.init();

  // Only initialize mobile-specific services on mobile platforms
  if (!kIsWeb) {
    await NotificationService.instance.init();
    // Small delay to ensure notification channels are created
    await Future.delayed(const Duration(milliseconds: 500));

    // Check and handle battery optimization BEFORE starting background service
    final batteryService = BatteryOptimizationService();
    await batteryService.checkAndHandleBatteryOptimization();

    // Initialize background service (server mode only)
    await BackgroundServiceController.initializeService();

    // Initialize FCM and favorite notification services
    // FCM initialization includes favorite subscriptions, so we do it first
    await BackendService.instance.initializeFCM();

    // Initialize favorite product notification monitoring
    // This will not re-subscribe to FCM topics since FCM is already initialized
    await FavoriteNotificationService.instance.initializeService();

    // Request basic permissions (mobile only) - notification permission excluded
    // as it will be requested during onboarding when user explicitly opts in
    await requestInitialPermissions();
  }

  runApp(const ZenRadarApp());
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
