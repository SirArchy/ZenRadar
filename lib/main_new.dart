import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zenradar/services/backend_service.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await NotificationService.instance.init();
  await initializeService();
  await BackendService.instance.initializeFCM();

  // Request permissions
  await requestPermissions();

  runApp(const ZenRadarApp());
}

Future<void> requestPermissions() async {
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
    return MaterialApp(
      title: 'ZenRadar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50), // Green theme for matcha
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
