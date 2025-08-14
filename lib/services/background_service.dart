// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/matcha_product.dart';
import '../models/scan_activity.dart';
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

  // Configure the service with enhanced foreground settings for maximum persistence
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
      isForegroundMode: true, // Critical for preventing service termination
      notificationChannelId: 'zenradar_foreground_service',
      initialNotificationTitle: 'ZenRadar Stock Monitor Active',
      initialNotificationContent: 'Continuously monitoring matcha availability',
      foregroundServiceNotificationId: 888,
      // Enhanced foreground service types for better persistence
      foregroundServiceTypes: [
        AndroidForegroundType.dataSync,
        AndroidForegroundType.connectedDevice, // For network operations
      ],
    ),
  );

  print('✅ Enhanced foreground service configured successfully');

  // Start the service after configuration
  print('Background service configured, attempting to start...');
  try {
    final isRunning = await service.isRunning();
    print('Service running status before start: $isRunning');

    if (!isRunning) {
      await service.startService();
      print('Background service start command sent');

      // Verify it actually started with multiple checks
      await Future.delayed(const Duration(seconds: 2));
      final isRunningAfter = await service.isRunning();
      print('Service running status after start: $isRunningAfter');

      if (!isRunningAfter) {
        print('⚠️ Warning: Service not running after start attempt');

        // Try starting again
        print('🔄 Attempting to start service again...');
        await service.startService();
        await Future.delayed(const Duration(seconds: 3));
        final isRunningSecondTry = await service.isRunning();
        print('Service running status after second try: $isRunningSecondTry');
      } else {
        print('✅ Background service started successfully!');

        // Give it time to initialize and send a test message
        await Future.delayed(const Duration(seconds: 5));
        try {
          print('🧪 Sending test message to background service...');
          await BackgroundServiceController.instance.triggerManualCheck();
          print('✅ Test message sent to background service');
        } catch (e) {
          print('❌ Failed to send test message: $e');
        }
      }
    } else {
      print('✅ Background service was already running');
    }
  } catch (e) {
    print('Failed to start background service: $e');
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  print('=== ZenRadar Enhanced Foreground Service Started ===');
  print('🕐 Service start time: ${DateTime.now()}');
  print('📱 Service type: ${service.runtimeType}');
  print('🛡️ Enhanced persistence mode: ACTIVE');

  try {
    DartPluginRegistrant.ensureInitialized();
    print('✅ DartPluginRegistrant initialized');

    // Record service start time for health monitoring
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'service_start_time',
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setInt(
        'service_last_heartbeat',
        DateTime.now().millisecondsSinceEpoch,
      );
      print('✅ Service start time recorded for monitoring');
    } catch (e) {
      print('⚠️ Failed to record service start time: $e');
    }

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
      print(
        '⚠️ Continuing without notifications - background scanning will still work',
      );
      // Don't return here - continue without notifications
    }

    // Enhanced foreground service configuration for maximum persistence
    if (service is AndroidServiceInstance) {
      print('🔧 Configuring enhanced Android foreground service...');

      try {
        // Set up foreground service event listeners for maximum control
        service.on('setAsForeground').listen((event) {
          print('📢 Received setAsForeground event');
          service.setAsForegroundService();
        });

        service.on('setAsBackground').listen((event) {
          print('📢 Received setAsBackground event - maintaining foreground');
          // Prevent background mode to avoid termination
          service.setAsForegroundService();
        });

        // Immediately ensure foreground mode
        service.setAsForegroundService();

        // Enhanced initial notification with persistence indicators
        service.setForegroundNotificationInfo(
          title: "ZenRadar - Enhanced Monitoring",
          content:
              "Protected foreground service • Continuous matcha monitoring active",
        );
        print('✅ Enhanced foreground notification set');

        // Critical: Add persistent heartbeat to prevent Android from killing the service
        Timer.periodic(const Duration(minutes: 2), (heartbeatTimer) async {
          try {
            // Ensure we're still in foreground mode
            if (await service.isForegroundService()) {
              // Update notification with heartbeat timestamp to prove service is alive
              final now = DateTime.now();
              final timeString =
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

              service.setForegroundNotificationInfo(
                title: "ZenRadar - Active Monitor",
                content:
                    "Protected Service ❤️ Active • Last pulse: $timeString",
              );

              print(
                '💓 Enhanced heartbeat ${heartbeatTimer.tick}: Service alive at $timeString',
              );
            } else {
              // Force back to foreground if somehow backgrounded
              print('⚠️ Service not in foreground - forcing foreground mode');
              service.setAsForegroundService();
              service.setForegroundNotificationInfo(
                title: "ZenRadar - Restored",
                content:
                    "Service restored to foreground mode • Monitoring resumed",
              );
            }
          } catch (e) {
            print('❌ Heartbeat error: $e');
            // Try to recover
            try {
              service.setAsForegroundService();
            } catch (recoveryError) {
              print('❌ Failed to recover foreground service: $recoveryError');
            }
          }
        });
      } catch (e) {
        print('❌ Failed to set enhanced foreground service: $e');
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
    DateTime? lastScanTime;

    // Function to start/restart the periodic timer with latest settings
    Future<void> reloadSettingsAndRestartTimer() async {
      currentTimer?.cancel();
      settings = await _getUserSettings();
      print(
        '🔄 Reloaded settings: ${settings.checkFrequencyMinutes} min intervals, active hours: ${settings.startTime}-${settings.endTime}',
      );
      lastScanTime = DateTime.now();
      currentTimer = Timer.periodic(Duration(minutes: settings.checkFrequencyMinutes), (
        timer,
      ) async {
        print('⏰ Timer triggered: ${DateTime.now()}');
        print(
          '🕐 Timer info: interval=${settings.checkFrequencyMinutes}min, tick=${timer.tick}',
        );
        print(
          '🔧 Active hours check: ${settings.startTime} - ${settings.endTime}',
        );

        if (service is AndroidServiceInstance) {
          try {
            if (await service.isForegroundService()) {
              // Update foreground notification based on active hours
              final isWithinHours = _isWithinActiveHours(settings);
              service.setForegroundNotificationInfo(
                title: "ZenRadar - Matcha Monitor",
                content:
                    isWithinHours
                        ? "Scanning matcha sites... (${timer.tick} scans completed)"
                        : "Paused - Outside active hours (${settings.startTime}-${settings.endTime})",
              );
              print('📱 Updated foreground notification (tick ${timer.tick})');
            }
          } catch (e) {
            print('⚠️ Failed to update foreground notification: $e');
          }
        }

        // Enhanced scanning with foreground service persistence checks
        if (_isWithinActiveHours(settings)) {
          print('✅ Within active hours, performing enhanced stock check...');

          try {
            // Ensure we're still in foreground mode before scanning
            if (service is AndroidServiceInstance) {
              if (!(await service.isForegroundService())) {
                print('⚠️ Service not in foreground during scan - restoring');
                service.setAsForegroundService();
              }

              service.setForegroundNotificationInfo(
                title: "ZenRadar - Active Scan",
                content: "🔍 Checking matcha availability • Protected Service",
              );
            }

            await _performStockCheck();

            // Reset lastScanTime after scan
            lastScanTime = DateTime.now();

            // Enhanced post-scan notification with persistence info
            if (service is AndroidServiceInstance) {
              if (await service.isForegroundService()) {
                final nextCheckTime = lastScanTime!.add(
                  Duration(minutes: settings.checkFrequencyMinutes),
                );
                final timeString =
                    '${nextCheckTime.hour.toString().padLeft(2, '0')}:${nextCheckTime.minute.toString().padLeft(2, '0')}';
                service.setForegroundNotificationInfo(
                  title: "ZenRadar - Monitoring Active",
                  content:
                      "✅ Scan complete • Next: $timeString • Service Protected",
                );
              } else {
                // Recovery: Force back to foreground if somehow lost
                print('🔧 Restoring foreground mode after scan');
                service.setAsForegroundService();
                service.setForegroundNotificationInfo(
                  title: "ZenRadar - Service Restored",
                  content: "Foreground mode restored • Monitoring continues",
                );
              }
            }

            print(
              '✅ Enhanced background stock check completed: ${DateTime.now()}',
            );
          } catch (e) {
            print('❌ Error during enhanced background stock check: $e');

            // Enhanced error handling with foreground service recovery
            if (service is AndroidServiceInstance) {
              try {
                service
                    .setAsForegroundService(); // Ensure we stay in foreground
                service.setForegroundNotificationInfo(
                  title: "ZenRadar - Scan Error",
                  content:
                      "❌ Scan failed • Will retry • Service remains protected",
                );
              } catch (notificationError) {
                print(
                  '❌ Failed to update error notification: $notificationError',
                );
              }
            }
          }
        } else {
          print(
            '⏭️ Enhanced background check skipped - outside active hours: ${DateTime.now()}',
          );

          // Update notification even when outside hours to show service is alive
          if (service is AndroidServiceInstance) {
            try {
              service.setForegroundNotificationInfo(
                title: "ZenRadar - Paused",
                content:
                    "⏸️ Outside hours (${settings.startTime}-${settings.endTime}) • Service protected",
              );
            } catch (e) {
              print('❌ Failed to update paused notification: $e');
            }
          }
        }
      });
      print(
        '✅ Timer started with ${settings.checkFrequencyMinutes} minute intervals',
      );
    }

    // Start initial timer with latest settings
    await reloadSettingsAndRestartTimer();

    // Add a test timer that fires every 30 seconds to verify timers work in background
    Timer.periodic(const Duration(seconds: 30), (testTimer) {
      print(
        '🧪 TEST TIMER: Background service alive - tick ${testTimer.tick} at ${DateTime.now()}',
      );
      if (service is AndroidServiceInstance) {
        try {
          lastScanTime ??= DateTime.now();
          final now = DateTime.now();
          final nextScanTime = lastScanTime!.add(
            Duration(minutes: settings.checkFrequencyMinutes),
          );
          final remaining = nextScanTime.difference(now);

          int hoursLeft = remaining.inHours;
          int minutesLeft = remaining.inMinutes % 60;
          if (remaining.isNegative) {
            hoursLeft = 0;
            minutesLeft = 0;
          }

          String timeText;
          if (hoursLeft > 0) {
            timeText =
                "$hoursLeft hour${hoursLeft == 1 ? '' : 's'} and $minutesLeft minute${minutesLeft == 1 ? '' : 's'}";
          } else {
            timeText = "$minutesLeft minute${minutesLeft == 1 ? '' : 's'}";
          }

          service.setForegroundNotificationInfo(
            title: "ZenRadar - Matcha Monitor",
            content: "Monitoring matcha stock - Next scan in $timeText",
          );
        } catch (e) {
          print('⚠️ Failed to update notification: $e');
        }
      }
    });

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
              title: "ZenRadar - Manual Scan",
              content: "Starting user-requested matcha stock check...",
            );
          }
        }

        // Manual checks ignore active hours and show detailed progress
        await _performStockCheck();
        print('✅ Manual stock check completed: ${DateTime.now()}');

        // Update foreground notification after manual check
        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            service.setForegroundNotificationInfo(
              title: "ZenRadar - Matcha Monitor",
              content: "Manual scan complete - Resuming automatic monitoring",
            );
          }
        }
        print('✅ Manual check confirmation updated');
      } catch (e) {
        print('❌ Error during manual stock check: $e');

        // Update foreground notification with error
        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            service.setForegroundNotificationInfo(
              title: "ZenRadar - Manual Scan Failed",
              content: "Check failed - Please try again or check network",
            );
          }
        }

        // Send error notification only if notifications are enabled
        final userSettings = await _getUserSettings();
        if (userSettings.notificationsEnabled) {
          await NotificationService.instance.showStockAlert(
            productName: 'Manual Check Error',
            siteName: 'Background Service',
            productId: 'error_${DateTime.now().millisecondsSinceEpoch}',
            productUrl: '',
          );
        }
      }
    });

    // Listen for settings updates
    service.on('updateSettings').listen((event) async {
      print('⚙️ Settings update command received, reloading configuration...');
      await reloadSettingsAndRestartTimer(); // Reload settings and restart timer
    });

    // Enhanced watchdog mechanism with foreground service health monitoring
    Timer.periodic(const Duration(minutes: 3), (watchdogTimer) async {
      try {
        // Use SharedPreferences to create a heartbeat mechanism
        final prefs = await SharedPreferences.getInstance();
        final lastHeartbeat = prefs.getInt('service_last_heartbeat') ?? 0;
        final currentTime = DateTime.now().millisecondsSinceEpoch;

        // If no heartbeat in the last 8 minutes, the service might be dead
        if (currentTime - lastHeartbeat > 8 * 60 * 1000) {
          print(
            '⚠️ Service heartbeat missed, service may have been terminated',
          );
          // The service will be restarted by the main app's watchdog mechanism
        }

        // Enhanced foreground service health check
        if (service is AndroidServiceInstance) {
          final isForeground = await service.isForegroundService();
          if (!isForeground) {
            print(
              '🚨 CRITICAL: Service not in foreground mode - forcing restoration',
            );
            try {
              service.setAsForegroundService();
              service.setForegroundNotificationInfo(
                title: "ZenRadar - Service Restored",
                content:
                    "⚡ Foreground mode restored by watchdog • Protection active",
              );
              print('✅ Foreground service restored by watchdog');
            } catch (e) {
              print('❌ Watchdog failed to restore foreground service: $e');
            }
          } else {
            // Service is healthy - update notification with watchdog status
            try {
              final now = DateTime.now();
              final timeString =
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
              service.setForegroundNotificationInfo(
                title: "ZenRadar - Protected Service",
                content:
                    "🛡️ Watchdog active • Service healthy • Last check: $timeString",
              );
            } catch (e) {
              print('⚠️ Failed to update watchdog notification: $e');
            }
          }
        }

        // Update heartbeat
        await prefs.setInt('service_last_heartbeat', currentTime);
        await prefs.setInt('service_watchdog_ticks', watchdogTimer.tick);
        print(
          '💓 Enhanced watchdog heartbeat ${watchdogTimer.tick}: Service healthy at ${DateTime.now()}',
        );

        // Log service statistics for debugging
        if (watchdogTimer.tick % 10 == 0) {
          // Every 30 minutes
          print('📊 Service health report:');
          print(
            '   🕐 Service uptime: ${((currentTime - (prefs.getInt('service_start_time') ?? currentTime)) / 1000 / 60).toStringAsFixed(1)} minutes',
          );
          print('   💓 Watchdog ticks: ${watchdogTimer.tick}');
          print(
            '   🔋 Battery optimizations: Check device settings if service stops',
          );
        }
      } catch (e) {
        print('❌ Error in enhanced service watchdog: $e');

        // Even on error, try to maintain foreground status
        if (service is AndroidServiceInstance) {
          try {
            service.setAsForegroundService();
          } catch (recoveryError) {
            print(
              '❌ Failed emergency foreground service restoration: $recoveryError',
            );
          }
        }
      }
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
        productUrl: '',
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
  final scanStartTime = DateTime.now();
  final stopwatch = Stopwatch()..start();

  try {
    print('🔍 Starting stock check: $scanStartTime');

    // Get user settings to see what sites are enabled and notification preferences
    final userSettings = await _getUserSettings();
    print(
      '⚙️ Enabled sites for stock check: ${userSettings.enabledSites.join(", ")}',
    );

    // Show stock check started notification with progress bar (with error handling)
    // Only show if notifications are enabled
    if (userSettings.notificationsEnabled) {
      try {
        await NotificationService.instance.showStockCheckStarted();
      } catch (e) {
        print('⚠️ Failed to show start notification: $e');
      }
    }

    // Initialize crawler
    final crawler = CrawlerService.instance;
    print('📡 Crawler instance created');

    // Check if we have favorite products and if user wants favorites-only background scanning
    final favoriteProductIds =
        await DatabaseService.platformService.getFavoriteProductIds();
    final hasFavorites = favoriteProductIds.isNotEmpty;
    final shouldScanFavoritesOnly =
        userSettings.backgroundScanFavoritesOnly && hasFavorites;

    String scanType = 'background';
    if (shouldScanFavoritesOnly) {
      scanType = 'favorites';
      print(
        '❤️ Favorites-only mode: Monitoring ${favoriteProductIds.length} favorite products (user preference: favorites only)',
      );
    } else if (hasFavorites && !userSettings.backgroundScanFavoritesOnly) {
      print(
        '🌍 Full monitoring mode: Checking all products on enabled sites (user preference: scan all, ${favoriteProductIds.length} favorites available)',
      );
    } else {
      print(
        '🌍 Full monitoring mode: Checking all products on enabled sites (no favorites set)',
      );
    }

    // Get previous products to compare for changes
    final previousProducts =
        shouldScanFavoritesOnly
            ? await DatabaseService.platformService.getFavoriteProducts()
            : await DatabaseService.platformService.getAllProducts();
    final Map<String, MatchaProduct> previousProductMap = {
      for (var product in previousProducts)
        '${product.site}_${product.normalizedName}': product,
    };

    // Track progress and new/updated products
    List<String> enabledSites = userSettings.enabledSites;
    final List<MatchaProduct> allNewProducts = [];
    final List<MatchaProduct> allUpdatedProducts = [];
    final List<String> sitesWithChanges = [];
    int totalNewProducts = 0;
    int totalUpdatedProducts = 0;

    // In favorites-only mode, only crawl sites that have favorite products
    if (shouldScanFavoritesOnly) {
      final favoriteProducts =
          await DatabaseService.platformService.getFavoriteProducts();
      final favoriteSites =
          favoriteProducts.map((p) => p.site).toSet().toList();

      // Create mapping from site keys to site names to handle the mismatch
      final Map<String, String> siteKeyToName = {
        'tokichi': 'Nakamura Tokichi',
        'marukyu': 'Marukyu-Koyamaen',
        'ippodo': 'Ippodo Tea',
        'yoshien': 'Yoshi En',
        'matcha-karu': 'Matcha Kāru',
        'sho-cha': 'Sho-Cha',
        'sazentea': 'Sazen Tea',
        'mamecha': 'Mamecha',
        'enjoyemeri': 'Emeri',
        'poppatea': 'Poppatea',
      };

      // Find which site keys correspond to sites that have favorites
      final siteKeysWithFavorites =
          enabledSites.where((siteKey) {
            final siteName = siteKeyToName[siteKey];
            return siteName != null && favoriteSites.contains(siteName);
          }).toList();

      enabledSites = siteKeysWithFavorites;
      print(
        '📋 Favorites-only mode: Will only crawl ${enabledSites.length} sites with favorites: ${enabledSites.join(", ")}',
      );
      print('📋 Favorite sites found: ${favoriteSites.join(", ")}');
    }

    // Update progress notification for each site as we crawl
    // Only show progress if notifications are enabled
    for (int i = 0; i < enabledSites.length; i++) {
      final siteName = enabledSites[i];

      if (userSettings.notificationsEnabled) {
        try {
          await NotificationService.instance.updateStockCheckProgress(
            siteName: siteName,
            currentSite: i + 1,
            totalSites: enabledSites.length,
          );
        } catch (e) {
          print('⚠️ Failed to update progress notification: $e');
        }
      }

      // Small delay to make progress visible and respect rate limits
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Crawl all enabled sites
    List<MatchaProduct> allProducts = await crawler.crawlSelectedSites(
      enabledSites,
    );
    print(
      '✅ Stock check completed. Found ${allProducts.length} total products.',
    );

    // Ensure all products are updated in the database with their latest stock state
    for (final product in allProducts) {
      await DatabaseService.platformService.insertOrUpdateProduct(product);
    }

    // In favorites mode, filter products to only include favorites
    List<MatchaProduct> productsToProcess;
    if (shouldScanFavoritesOnly) {
      productsToProcess =
          allProducts
              .where((product) => favoriteProductIds.contains(product.id))
              .toList();
      print(
        '❤️ Filtered to ${productsToProcess.length} favorite products for monitoring',
      );
    } else {
      productsToProcess = allProducts;
    }

    // Compare with previous products to find new and updated items
    for (var product in productsToProcess) {
      final productKey = '${product.site}_${product.normalizedName}';
      final previousProduct = previousProductMap[productKey];

      if (previousProduct == null) {
        // Completely new product (or newly added to favorites)
        allNewProducts.add(product);
        totalNewProducts++;

        if (!sitesWithChanges.contains(product.site)) {
          sitesWithChanges.add(product.site);
        }
      } else if (previousProduct.isInStock != product.isInStock) {
        // Stock status changed
        allUpdatedProducts.add(product);
        totalUpdatedProducts++;

        if (!sitesWithChanges.contains(product.site)) {
          sitesWithChanges.add(product.site);
        }

        // Log stock status changes
        if (product.isInStock && !previousProduct.isInStock) {
          print('📈 Stock restored: ${product.name} on ${product.site}');
        } else if (!product.isInStock && previousProduct.isInStock) {
          print('📉 Stock depleted: ${product.name} on ${product.site}');
        }
      }
    }

    // Hide progress notification
    // Only try to hide if notifications are enabled (meaning we showed one)
    if (userSettings.notificationsEnabled) {
      try {
        await NotificationService.instance.hideStockCheckProgress();
      } catch (e) {
        print('⚠️ Failed to hide progress notification: $e');
      }
    }

    // Show completion notification based on what we found
    if (totalNewProducts > 0 || totalUpdatedProducts > 0) {
      // Only show completion notification if notifications are enabled
      if (userSettings.notificationsEnabled) {
        try {
          await NotificationService.instance.showStockCheckCompleted(
            totalProducts:
                shouldScanFavoritesOnly
                    ? productsToProcess.length
                    : allProducts.length,
            newProducts: totalNewProducts,
            updatedSites: sitesWithChanges,
          );
        } catch (e) {
          print('⚠️ Failed to show completion notification: $e');
        }
      }

      // Also send individual stock alerts for products that came back in stock
      // Only if notifications are enabled
      if (userSettings.notificationsEnabled) {
        for (var product in allUpdatedProducts) {
          if (product.isInStock) {
            try {
              await NotificationService.instance.showStockAlert(
                productName: product.name,
                siteName: product.site,
                productId: product.id,
                productUrl: product.url,
              );
            } catch (e) {
              print('⚠️ Failed to show stock alert for ${product.name}: $e');
            }
          }
        }
      }
    } else {
      // No changes found - just log it, don't spam with notifications
      final modeText =
          shouldScanFavoritesOnly ? 'favorite products' : 'products';
      print('✅ Stock check completed - no changes detected in $modeText');
    }

    final modeText =
        shouldScanFavoritesOnly
            ? '${favoriteProductIds.length} favorite products'
            : 'all products';
    print(
      '📊 Stock check summary ($modeText): $totalNewProducts new products, $totalUpdatedProducts stock changes across ${sitesWithChanges.length} sites',
    );

    // Log scan activity
    stopwatch.stop();
    final scanActivity = ScanActivity(
      id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: scanStartTime,
      itemsScanned: allProducts.length, // Always show total products scanned
      duration: stopwatch.elapsed.inSeconds,
      hasStockUpdates: totalNewProducts > 0 || totalUpdatedProducts > 0,
      details:
          shouldScanFavoritesOnly
              ? 'Monitored ${favoriteProductIds.length} favorite products from ${enabledSites.length} sites (favorites-only mode)'
              : 'Full scan of ${enabledSites.join(", ")}',
      scanType: scanType,
    );

    try {
      await DatabaseService.platformService.insertScanActivity(scanActivity);
      print(
        '✅ Scan activity logged: ${scanActivity.itemsScanned} items in ${scanActivity.formattedDuration}',
      );
    } catch (e) {
      print('⚠️ Failed to log scan activity: $e');
    }
  } catch (e) {
    print('❌ Error during stock check: $e');

    // Hide progress notification on error
    // Only try to hide if notifications are enabled (meaning we showed one)
    final userSettings = await _getUserSettings();
    if (userSettings.notificationsEnabled) {
      await NotificationService.instance.hideStockCheckProgress();
    }

    // Send error notification only if notifications are enabled
    if (userSettings.notificationsEnabled) {
      await NotificationService.instance.showStockAlert(
        productName: 'Stock Check Failed',
        siteName: 'System Error',
        productId: 'error_${DateTime.now().millisecondsSinceEpoch}',
        productUrl: '',
      );
    }

    // Log failed scan activity
    stopwatch.stop();
    final scanActivity = ScanActivity(
      id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: scanStartTime,
      itemsScanned: 0,
      duration: stopwatch.elapsed.inSeconds,
      hasStockUpdates: false,
      details: 'Scan failed: $e',
      scanType: 'background',
    );

    try {
      await DatabaseService.platformService.insertScanActivity(scanActivity);
      print('✅ Failed scan activity logged');
    } catch (logError) {
      print('⚠️ Failed to log scan activity: $logError');
    }

    rethrow; // Re-throw to let caller handle it
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

  // Return default settings for testing with shorter intervals
  return UserSettings(
    checkFrequencyMinutes: 10, // 10 minutes for testing
    startTime: "08:00",
    endTime: "20:00",
    notificationsEnabled: true,
    enabledSites: const ["tokichi", "marukyu", "ippodo"],
  );
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

    // Check if current time is within the active period (inclusive of start and end times)
    final isWithinHours =
        (now.isAfter(startTime) || now.isAtSameMomentAs(startTime)) &&
        (now.isBefore(endTime) || now.isAtSameMomentAs(endTime));

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

  /// Start a watchdog mechanism to monitor and restart the service if needed
  void startServiceWatchdog() {
    if (kIsWeb) {
      // Web doesn't need watchdog as it handles its own lifecycle
      return;
    }

    Timer.periodic(const Duration(minutes: 3), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastHeartbeat = prefs.getInt('service_last_heartbeat') ?? 0;
        final currentTime = DateTime.now().millisecondsSinceEpoch;

        // If no heartbeat in the last 8 minutes, restart the service
        if (currentTime - lastHeartbeat > 8 * 60 * 1000) {
          print('🚨 Service heartbeat timeout detected, restarting service...');

          final isRunning = await isServiceRunning();
          if (!isRunning) {
            print('⚠️ Service confirmed as not running, attempting restart...');
            await startService();
            print('✅ Service restart attempted');
          } else {
            print('ℹ️ Service reports as running despite heartbeat timeout');
          }
        }
      } catch (e) {
        print('❌ Error in service watchdog: $e');
      }
    });

    print('🐕 Service watchdog started');
  }
}
