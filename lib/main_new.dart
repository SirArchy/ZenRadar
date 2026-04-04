import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:zenradar/data/services/services.dart';
import 'package:zenradar/presentation/screens/screens.dart';

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
      onGenerateTitle:
          (context) => AppLocalizations.of(context)?.appName ?? 'ZenRadar',
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
