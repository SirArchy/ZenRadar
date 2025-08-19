import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'services/database_service.dart';
import 'services/theme_service.dart';
import 'services/battery_optimization_service.dart';
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

    // Initialize background service (will check app mode internally)
    await initializeService();

    // Request permissions (mobile only) - but exclude notification permission
    // as it will be requested during onboarding
    await requestInitialPermissions();
  }

  runApp(const ZenRadarApp());
}

Future<void> requestInitialPermissions() async {
  if (kIsWeb) return; // Skip permissions on web

  // Request background app refresh permission (iOS)
  await Permission.appTrackingTransparency.request();

  // Check and handle battery optimization
  final batteryService = BatteryOptimizationService();
  await batteryService.checkAndHandleBatteryOptimization();
}

// Legacy function for requesting all permissions (including notifications)
Future<void> requestPermissions() async {
  if (kIsWeb) return; // Skip permissions on web

  // Request notification permission
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
