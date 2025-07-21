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

  // Configure the service with proper Android settings
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
      isForegroundMode: true, // Changed to true for better reliability
      notificationChannelId: 'zenradar_background',
      initialNotificationTitle: 'ZenRadar Monitoring',
      initialNotificationContent:
          'Monitoring matcha stock availability in background',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
  );

  // Start the service after configuration
  print('Background service configured, attempting to start...');
  try {
    await service.startService();
    print('Background service started successfully');
  } catch (e) {
    print('Failed to start background service: $e');
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  print('=== ZenRadar Background Service Started ===');

  try {
    DartPluginRegistrant.ensureInitialized();
    print('✅ DartPluginRegistrant initialized');

    // Initialize services with error handling
    try {
      await DatabaseService.platformService.initDatabase();
      print('✅ Database service initialized');
    } catch (e) {
      print('❌ Failed to initialize database: $e');
      return;
    }

    try {
      await NotificationService.instance.init();
      print('✅ Notification service initialized');
    } catch (e) {
      print('❌ Failed to initialize notifications: $e');
      return;
    }

    // Ensure background notification channel exists
    if (service is AndroidServiceInstance) {
      try {
        service.setForegroundNotificationInfo(
          title: "ZenRadar Monitoring",
          content: "Matcha stock monitoring active...",
        );
        print('✅ Foreground notification set');
      } catch (e) {
        print('❌ Failed to set foreground notification: $e');
      }
    }

    // Get user settings
    UserSettings settings;
    try {
      settings = await _getUserSettings();
      print(
        '✅ User settings loaded: ${settings.checkFrequencyMinutes} min intervals',
      );
      print('   Active hours: ${settings.startTime} - ${settings.endTime}');
      print('   Enabled sites: ${settings.enabledSites.join(", ")}');
    } catch (e) {
      print('❌ Failed to load user settings: $e');
      settings = UserSettings(); // Use defaults
    }

    Timer? currentTimer;

    // Function to start/restart the periodic timer
    void startPeriodicTimer() {
      currentTimer?.cancel(); // Cancel existing timer if any
      print(
        '🔄 Starting timer with ${settings.checkFrequencyMinutes} minute intervals',
      );

      currentTimer = Timer.periodic(Duration(minutes: settings.checkFrequencyMinutes), (
        timer,
      ) async {
        print('⏰ Timer triggered: ${DateTime.now()}');

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
            print('📱 Updated foreground notification');
          }
        }

        // Check if we're within active hours before performing stock check
        if (_isWithinActiveHours(settings)) {
          print('✅ Within active hours, performing stock check...');

          // Update foreground notification to show stock check in progress
          if (service is AndroidServiceInstance) {
            if (await service.isForegroundService()) {
              service.setForegroundNotificationInfo(
                title: "ZenRadar - Checking Stock",
                content: "Scanning matcha websites for updates...",
              );
            }
          }

          await _performStockCheck();

          // Update foreground notification after stock check
          if (service is AndroidServiceInstance) {
            if (await service.isForegroundService()) {
              service.setForegroundNotificationInfo(
                title: "ZenRadar Active",
                content:
                    "Last check: ${DateTime.now().toString().substring(0, 16)}",
              );
            }
          }

          print('✅ Background stock check completed: ${DateTime.now()}');
        } else {
          print(
            '⏭️ Background check skipped - outside active hours: ${DateTime.now()}',
          );
        }
      });

      print(
        '✅ Timer started with ${settings.checkFrequencyMinutes} minute intervals',
      );
    }

    // Start initial timer
    startPeriodicTimer();

    // Test notification to verify service is working
    try {
      await NotificationService.instance.showTestNotification();
      print('✅ Test notification sent successfully');
    } catch (e) {
      print('❌ Failed to send test notification: $e');
    }

    // Listen for stop commands
    service.on('stopService').listen((event) {
      print('🛑 Stop service command received');
      currentTimer?.cancel();
      service.stopSelf();
    });

    // Listen for manual check commands
    service.on('manualCheck').listen((event) async {
      print('🚀 Manual check command received');
      print('🔍 Current time: ${DateTime.now()}');
      print('⚙️ Settings: ${settings.enabledSites.join(", ")}');

      try {
        // Update foreground notification for manual check
        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            service.setForegroundNotificationInfo(
              title: "ZenRadar - Manual Check",
              content: "Performing manual stock check...",
            );
          }
        }

        // Manual checks ignore active hours and use new notification system
        await _performStockCheck();
        print('✅ Manual stock check completed: ${DateTime.now()}');

        // Update foreground notification after manual check
        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            service.setForegroundNotificationInfo(
              title: "ZenRadar Active",
              content:
                  "Manual check completed: ${DateTime.now().toString().substring(0, 16)}",
            );
          }
        }
        print('✅ Confirmation notification sent');
      } catch (e) {
        print('❌ Error during manual stock check: $e');

        // Send error notification
        await NotificationService.instance.showStockAlert(
          productName: 'Manual Check Error',
          siteName: 'Background Service',
          productId: 'error_${DateTime.now().millisecondsSinceEpoch}',
        );
      }
    });

    // Listen for settings updates
    service.on('updateSettings').listen((event) async {
      print('⚙️ Settings update command received, reloading configuration...');
      settings = await _getUserSettings();
      startPeriodicTimer(); // Restart timer with new frequency
    });

    print('✅ Background service fully initialized and running');
  } catch (e) {
    print('❌ Critical error in background service: $e');
    // Try to send an error notification
    try {
      await NotificationService.instance.showStockAlert(
        productName: 'Background Service Error',
        siteName: 'System',
        productId: 'error_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (notifError) {
      print('❌ Failed to send error notification: $notifError');
    }
  }
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
    print('🔍 Starting stock check: ${DateTime.now()}');

    // Show stock check started notification
    await NotificationService.instance.showStockCheckStarted();

    // Initialize crawler
    final crawler = CrawlerService.instance;
    print('📡 Crawler instance created');

    // Get user settings to see what sites are enabled
    final userSettings = await _getUserSettings();
    print(
      '⚙️ Enabled sites for stock check: ${userSettings.enabledSites.join(", ")}',
    );

    // Get previous products to compare for changes
    final previousProducts =
        await DatabaseService.platformService.getProducts();
    final Map<String, MatchaProduct> previousProductMap = {
      for (var product in previousProducts)
        '${product.site}_${product.name}_${product.price}': product,
    };

    // Track progress and new products
    int currentSiteIndex = 0;
    final List<String> enabledSites = userSettings.enabledSites;
    final List<MatchaProduct> allNewProducts = [];
    final List<String> updatedSites = [];
    final Map<String, List<MatchaProduct>> newProductsBySite = {};

    // Update progress notification for each site
    for (final siteName in enabledSites) {
      currentSiteIndex++;
      await NotificationService.instance.updateStockCheckProgress(
        siteName: siteName,
        currentSite: currentSiteIndex,
        totalSites: enabledSites.length,
      );

      // Small delay to make progress visible
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Crawl all sites
    List<MatchaProduct> products = await crawler.crawlAllSites();
    print('✅ Stock check completed. Found ${products.length} products.');

    // Compare with previous products to find new items
    int newProductCount = 0;
    for (var product in products) {
      final productKey = '${product.site}_${product.name}_${product.price}';
      if (!previousProductMap.containsKey(productKey)) {
        allNewProducts.add(product);
        newProductCount++;

        // Group by site for summary
        newProductsBySite.putIfAbsent(product.site, () => []).add(product);

        if (!updatedSites.contains(product.site)) {
          updatedSites.add(product.site);
        }
      }
    }

    // Hide progress notification
    await NotificationService.instance.hideStockCheckProgress();

    // Show completion notification if there are new products
    if (newProductCount > 0) {
      await NotificationService.instance.showStockCheckCompleted(
        totalProducts: products.length,
        newProducts: newProductCount,
        updatedSites: updatedSites,
      );

      // Show individual stock alerts for high-priority new items
      for (var product in allNewProducts.take(5)) {
        // Limit to 5 to avoid spam
        if (product.isInStock) {
          await NotificationService.instance.showStockAlert(
            productName: product.name,
            siteName: product.site,
            productId: '${product.site}_${product.name}'.hashCode.toString(),
          );

          // Small delay between notifications
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    }

    // Log some details about what was found
    Map<String, int> productsBySite = {};
    for (var product in products) {
      productsBySite[product.site] = (productsBySite[product.site] ?? 0) + 1;
    }

    print('📊 Products by site:');
    productsBySite.forEach((site, count) {
      print('  - $site: $count products');
    });

    if (newProductCount > 0) {
      print('🆕 New products found:');
      newProductsBySite.forEach((site, products) {
        print('  - $site: ${products.length} new products');
        for (var product in products.take(3)) {
          // Show first 3
          print('    * ${product.name} - ${product.price ?? "No price"}');
        }
      });
    }

    // Clean up old history records
    await DatabaseService.platformService.deleteOldHistory();
    print('🧹 Old history cleaned up');
  } catch (e) {
    print('❌ Error during stock check: $e');
    print('📍 Stack trace: ${StackTrace.current}');

    // Hide progress notification on error
    await NotificationService.instance.hideStockCheckProgress();
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
