import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'services/database_service.dart';
import 'services/theme_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await DatabaseService.platformService.initDatabase();
  await ThemeService.instance.init();

  // Only initialize mobile-specific services on mobile platforms
  if (!kIsWeb) {
    await NotificationService.instance.init();
    // Small delay to ensure notification channels are created
    await Future.delayed(const Duration(milliseconds: 500));
    await initializeService();

    // Request permissions (mobile only)
    await requestPermissions();
  }

  runApp(const ZenRadarApp());
}

Future<void> requestPermissions() async {
  if (kIsWeb) return; // Skip permissions on web

  // Request notification permission
  await Permission.notification.isDenied.then((value) {
    if (value) {
      Permission.notification.request();
    }
  });

  // Request background app refresh permission (iOS)
  await Permission.appTrackingTransparency.request();
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
          home: const HomeScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
