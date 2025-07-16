// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/matcha_product.dart';
import 'crawler_service.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'web_background_service.dart';

Future<void> initializeService() async {
  // Skip background service initialization on web
  if (kIsWeb) {
    return;
  }

  final service = FlutterBackgroundService();

  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
    androidConfiguration: AndroidConfiguration(
      autoStart: true,
      onStart: onStart,
      autoStartOnBoot: true,
      isForegroundMode: false,
      notificationChannelId: 'zenradar_bg',
      initialNotificationTitle: 'ZenRadar Background Service',
      initialNotificationContent: 'Monitoring matcha stock...',
      foregroundServiceNotificationId: 888,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Initialize services
  await DatabaseService.platformService.initDatabase();
  await NotificationService.instance.init();

  // Get user settings
  UserSettings settings = await _getUserSettings();

  // Set up periodic timer based on user settings
  Timer.periodic(Duration(hours: settings.checkFrequencyHours), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // Update foreground notification
        service.setForegroundNotificationInfo(
          title: "ZenRadar Active",
          content: "Last check: ${DateTime.now().toString().substring(0, 16)}",
        );
      }
    }

    // Check if we're within active hours
    if (_isWithinActiveHours(settings)) {
      await _performStockCheck();
    }

    print('Background task completed: ${DateTime.now()}');
  });

  // Listen for stop commands
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Listen for manual check commands
  service.on('manualCheck').listen((event) async {
    await _performStockCheck();
  });

  // Listen for settings updates
  service.on('updateSettings').listen((event) async {
    // Reload settings - in a real implementation, you might restart the timer
    settings = await _getUserSettings();
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // iOS background execution is limited, perform quick check
  UserSettings settings = await _getUserSettings();
  if (_isWithinActiveHours(settings)) {
    await _performStockCheck();
  }

  return true;
}

Future<void> _performStockCheck() async {
  try {
    print('Starting stock check: ${DateTime.now()}');

    // Crawl all sites
    final crawler = CrawlerService.instance;
    List<MatchaProduct> products = await crawler.crawlAllSites();

    print('Stock check completed. Found ${products.length} products.');

    // Clean up old history records
    await DatabaseService.platformService.deleteOldHistory();
  } catch (e) {
    print('Error during stock check: $e');
  }
}

Future<UserSettings> _getUserSettings() async {
  final prefs = await SharedPreferences.getInstance();
  final settingsJson = prefs.getString('user_settings');

  if (settingsJson != null) {
    try {
      return UserSettings.fromJson(
        Map<String, dynamic>.from(
          // In a real app, you'd use a JSON decoder here
          {},
        ),
      );
    } catch (e) {
      print('Error parsing settings: $e');
    }
  }

  // Return default settings
  return UserSettings();
}

bool _isWithinActiveHours(UserSettings settings) {
  final now = DateTime.now();

  // Simple time comparison - in production you'd want more robust time handling
  final startHour = int.parse(settings.startTime.split(':')[0]);
  final endHour = int.parse(settings.endTime.split(':')[0]);
  final currentHour = now.hour;

  if (startHour <= endHour) {
    // Same day range (e.g., 08:00 to 20:00)
    return currentHour >= startHour && currentHour <= endHour;
  } else {
    // Overnight range (e.g., 20:00 to 08:00)
    return currentHour >= startHour || currentHour <= endHour;
  }
}

class BackgroundServiceController {
  static final BackgroundServiceController _instance =
      BackgroundServiceController._internal();
  factory BackgroundServiceController() => _instance;
  BackgroundServiceController._internal();

  static BackgroundServiceController get instance => _instance;

  // Use platform-specific service
  dynamic get _service {
    if (kIsWeb) {
      return WebBackgroundServiceController.instance;
    } else {
      return FlutterBackgroundService();
    }
  }

  Future<void> startService() async {
    if (kIsWeb) {
      await (_service as WebBackgroundServiceController).startService();
    } else {
      await (_service as FlutterBackgroundService).startService();
    }
  }

  Future<void> stopService() async {
    if (kIsWeb) {
      (_service as WebBackgroundServiceController).stopService();
    } else {
      (_service as FlutterBackgroundService).invoke('stopService');
    }
  }

  Future<void> triggerManualCheck() async {
    if (kIsWeb) {
      await (_service as WebBackgroundServiceController).triggerManualCheck();
    } else {
      (_service as FlutterBackgroundService).invoke('manualCheck');
    }
  }

  Future<void> updateSettings() async {
    if (kIsWeb) {
      await (_service as WebBackgroundServiceController).updateSettings();
    } else {
      (_service as FlutterBackgroundService).invoke('updateSettings');
    }
  }

  Future<bool> isServiceRunning() async {
    if (kIsWeb) {
      return await (_service as WebBackgroundServiceController)
          .isServiceRunning();
    } else {
      return await (_service as FlutterBackgroundService).isRunning();
    }
  }
}
