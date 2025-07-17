// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
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
  Timer? currentTimer;

  // Function to start/restart the periodic timer
  void startPeriodicTimer() {
    currentTimer?.cancel(); // Cancel existing timer if any

    currentTimer = Timer.periodic(
      Duration(minutes: settings.checkFrequencyMinutes),
      (timer) async {
        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            // Update foreground notification based on active hours
            final isWithinHours = _isWithinActiveHours(settings);
            service.setForegroundNotificationInfo(
              title: "ZenRadar ${isWithinHours ? 'Active' : 'Paused'}",
              content:
                  isWithinHours
                      ? "Last check: ${DateTime.now().toString().substring(0, 16)}"
                      : "Outside active hours (${settings.startTime}-${settings.endTime})",
            );
          }
        }

        // Check if we're within active hours before performing stock check
        if (_isWithinActiveHours(settings)) {
          await _performStockCheck();
          print('Background stock check completed: ${DateTime.now()}');
        } else {
          print(
            'Background check skipped - outside active hours: ${DateTime.now()}',
          );
        }
      },
    );

    print(
      'Timer started with ${settings.checkFrequencyMinutes} minute intervals',
    );
  }

  // Start initial timer
  startPeriodicTimer();

  // Listen for stop commands
  service.on('stopService').listen((event) {
    currentTimer?.cancel();
    service.stopSelf();
  });

  // Listen for manual check commands
  service.on('manualCheck').listen((event) async {
    // Manual checks ignore active hours
    await _performStockCheck();
    print('Manual stock check completed: ${DateTime.now()}');
  });

  // Listen for settings updates
  service.on('updateSettings').listen((event) async {
    print('Received settings update, reloading configuration...');
    settings = await _getUserSettings();
    startPeriodicTimer(); // Restart timer with new frequency
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
      final Map<String, dynamic> settingsMap = json.decode(settingsJson);
      return UserSettings.fromJson(settingsMap);
    } catch (e) {
      print('Error parsing settings: $e');
    }
  }

  // Return default settings
  return UserSettings();
}

bool _isWithinActiveHours(UserSettings settings) {
  final now = DateTime.now();

  try {
    // Parse start and end times
    final startParts = settings.startTime.split(':');
    final endParts = settings.endTime.split(':');

    if (startParts.length != 2 || endParts.length != 2) {
      print('Invalid time format in settings, allowing monitoring');
      return true; // Default to allowing monitoring if time format is invalid
    }

    final startHour = int.parse(startParts[0]);
    final startMinute = int.parse(startParts[1]);
    final endHour = int.parse(endParts[0]);
    final endMinute = int.parse(endParts[1]);

    // Validate hour and minute ranges
    if (startHour < 0 ||
        startHour > 23 ||
        endHour < 0 ||
        endHour > 23 ||
        startMinute < 0 ||
        startMinute > 59 ||
        endMinute < 0 ||
        endMinute > 59) {
      print('Invalid time values in settings, allowing monitoring');
      return true;
    }

    // Create DateTime objects for today's start and end times
    final today = DateTime(now.year, now.month, now.day);
    final startTime = today.add(
      Duration(hours: startHour, minutes: startMinute),
    );
    var endTime = today.add(Duration(hours: endHour, minutes: endMinute));

    // Handle overnight periods (e.g., 22:00 to 06:00)
    if (endTime.isBefore(startTime) || endTime.isAtSameMomentAs(startTime)) {
      // End time is next day
      endTime = endTime.add(const Duration(days: 1));
    }

    // Check if current time is within the active period
    final isWithinHours = now.isAfter(startTime) && now.isBefore(endTime);

    print(
      'Active hours check: ${settings.startTime}-${settings.endTime}, '
      'Current: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}, '
      'Within hours: $isWithinHours',
    );

    return isWithinHours;
  } catch (e) {
    print('Error parsing active hours: $e, allowing monitoring');
    return true; // Default to allowing monitoring if parsing fails
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
