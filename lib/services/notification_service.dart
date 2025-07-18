// ignore_for_file: avoid_print

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'web_notification_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) {
      await WebNotificationService.instance.init();
      return;
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // Create notification channels
    await _createNotificationChannels();

    // Request permissions for Android 13+
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  Future<void> _createNotificationChannels() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        try {
          // Create background service notification channel
          const AndroidNotificationChannel backgroundChannel =
              AndroidNotificationChannel(
                'zenradar_background',
                'Background Service',
                description:
                    'Persistent notification for background monitoring service',
                importance: Importance.low,
                showBadge: false,
                enableVibration: false,
                playSound: false,
              );

          // Create stock alerts notification channel
          const AndroidNotificationChannel stockAlertsChannel =
              AndroidNotificationChannel(
                'stock_alerts',
                'Stock Alerts',
                description: 'Notifications when matcha comes back in stock',
                importance: Importance.high,
                showBadge: true,
                enableVibration: true,
                playSound: true,
              );

          await androidImplementation.createNotificationChannel(
            backgroundChannel,
          );
          await androidImplementation.createNotificationChannel(
            stockAlertsChannel,
          );
          print('Notification channels created successfully');
        } catch (e) {
          print('Error creating notification channels: $e');
        }
      }
    }
  }

  void onDidReceiveNotificationResponse(
    NotificationResponse notificationResponse,
  ) async {
    final String? payload = notificationResponse.payload;
    if (notificationResponse.payload != null) {
      debugPrint('notification payload: $payload');
    }
  }

  Future<void> showStockAlert({
    required String productName,
    required String siteName,
    required String productId,
  }) async {
    if (kIsWeb) {
      await WebNotificationService.instance.showStockAlert(
        productName: productName,
        siteName: siteName,
        productId: productId,
      );
      return;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'stock_alerts',
          'Stock Alerts',
          channelDescription: 'Notifications when matcha comes back in stock',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@drawable/notification_icon',
          color: Color(0xFF4CAF50),
          playSound: true,
          enableVibration: true,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      productId.hashCode,
      '🍵 Matcha Back in Stock!',
      '$productName is now available on $siteName',
      platformChannelSpecifics,
      payload: productId,
    );
  }

  Future<void> showSummaryNotification({
    required List<String> productNames,
    required String siteName,
  }) async {
    if (kIsWeb) {
      await WebNotificationService.instance.showSummaryNotification(
        productNames: productNames,
        siteName: siteName,
      );
      return;
    }

    if (productNames.isEmpty) return;

    String title = '🍵 New Matcha Available!';
    String body;

    if (productNames.length == 1) {
      body = '${productNames.first} is now in stock on $siteName';
    } else {
      body =
          '${productNames.length} matcha products are now in stock on $siteName';
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'stock_summary',
          'Stock Summary',
          channelDescription:
              'Summary notifications for multiple stock updates',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@drawable/notification_icon',
          color: const Color(0xFF4CAF50),
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(
            '$body\n\nProducts: ${productNames.join(", ")}',
          ),
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      'summary_$siteName'.hashCode,
      title,
      body,
      platformChannelSpecifics,
      payload: 'summary_$siteName',
    );
  }

  Future<void> showTestNotification() async {
    if (kIsWeb) {
      await WebNotificationService.instance.showTestNotification();
      return;
    }

    await showStockAlert(
      productName: 'Test Matcha',
      siteName: 'Test Site',
      productId: 'test_123',
    );
  }

  Future<void> cancelAll() async {
    if (kIsWeb) {
      await WebNotificationService.instance.cancelAll();
      return;
    }

    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) {
      await WebNotificationService.instance.cancelNotification(id);
      return;
    }

    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<bool> checkPermissions() async {
    if (kIsWeb) {
      // For web, just return true for now
      return true;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      final bool? granted =
          await androidImplementation?.areNotificationsEnabled();
      print('🔔 Android notification permissions granted: $granted');
      return granted ?? false;
    }

    // For iOS, assume permissions are granted if initialization was successful
    return true;
  }

  Future<void> debugNotificationSystem() async {
    print('🔍 Debugging notification system...');

    try {
      // Check permissions
      final hasPermissions = await checkPermissions();
      print('📱 Notification permissions: $hasPermissions');

      // Try to show a simple test notification
      await showTestNotification();
      print('✅ Test notification attempted');

      // Check notification channels (Android)
      if (defaultTargetPlatform == TargetPlatform.android) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();

        if (androidImplementation != null) {
          print('📢 Android notification implementation available');
        } else {
          print('❌ Android notification implementation not available');
        }
      }
    } catch (e) {
      print('❌ Error debugging notification system: $e');
    }
  }
}
