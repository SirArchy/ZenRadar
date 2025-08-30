// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/database_service.dart';

/// Firebase Cloud Messaging service for handling push notifications
/// Enables notifications even when app is closed/in background
class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  static FirebaseMessagingService get instance => _instance;

  FirebaseMessaging? _messaging;
  String? _fcmToken;
  bool _isInitialized = false;

  /// Initialize Firebase Cloud Messaging
  Future<void> initialize() async {
    if (kIsWeb) {
      if (kDebugMode) {
        print('🌐 FCM: Web platform - using web notifications');
      }
      return;
    }

    try {
      _messaging = FirebaseMessaging.instance;

      // Request notification permissions
      final settings = await _messaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('🔔 FCM: Permission granted: ${settings.authorizationStatus}');
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token for this device
        _fcmToken = await _messaging!.getToken();
        if (kDebugMode) {
          print('📱 FCM Token: $_fcmToken');
        }

        // Save token to user preferences and send to server
        await _saveFCMToken();

        // Configure message handlers
        await _configureMessageHandlers();

        _isInitialized = true;
        if (kDebugMode) {
          print('✅ FCM: Successfully initialized');
        }
      } else {
        if (kDebugMode) {
          print('❌ FCM: Permission denied');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to initialize: $e');
      }
    }
  }

  /// Configure message handlers for different app states
  Future<void> _configureMessageHandlers() async {
    if (_messaging == null) return;

    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle messages when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Handle messages when app is terminated (requires static handler)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Check if app was opened from a terminated state by a notification
    final initialMessage = await _messaging!.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }
  }

  /// Handle messages when app is in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('📨 FCM: Foreground message received');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');
    }

    // Show local notification even when app is in foreground
    await _showLocalNotification(message);
  }

  /// Handle messages when app is opened from background
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('📨 FCM: Background message opened');
      print('Data: ${message.data}');
    }

    // Handle navigation based on message data
    await _handleNotificationNavigation(message.data);
  }

  /// Show local notification for FCM message
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;

      if (notification != null) {
        await NotificationService.instance.showNotification(
          id: message.hashCode,
          title: notification.title ?? 'ZenRadar',
          body: notification.body ?? 'New update available',
          payload: jsonEncode(message.data),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to show local notification: $e');
      }
    }
  }

  /// Handle navigation when notification is tapped
  Future<void> _handleNotificationNavigation(Map<String, dynamic> data) async {
    try {
      final type = data['type'];
      final productId = data['productId'];

      if (kDebugMode) {
        print(
          '🔗 FCM: Handling navigation - type: $type, productId: $productId',
        );
      }

      // Here you would implement navigation logic
      // For example, navigate to product detail page
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to handle navigation: $e');
      }
    }
  }

  /// Save FCM token to preferences and sync with server
  Future<void> _saveFCMToken() async {
    if (_fcmToken == null) return;

    try {
      final settings = await SettingsService.instance.getSettings();
      await SettingsService.instance.saveSettings(
        settings.copyWith(fcmToken: _fcmToken),
      );

      // TODO: Send token to your server to enable push notifications
      // This would typically involve calling an API endpoint
      // await _sendTokenToServer(_fcmToken!);

      if (kDebugMode) {
        print('💾 FCM: Token saved locally');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to save token: $e');
      }
    }
  }

  /// Send stock alert notification via FCM
  Future<void> sendStockAlert({
    required String productName,
    required String siteName,
    required String productId,
    required String productUrl,
  }) async {
    // This would typically be called from your server
    // The server would use the FCM admin SDK to send push notifications
    // to all devices that have the app installed and have favorited this product

    if (kDebugMode) {
      print('📤 FCM: Would send stock alert for $productName');
    }
  }

  /// Send price change notification via FCM
  Future<void> sendPriceAlert({
    required String productName,
    required String siteName,
    required String productId,
    required String oldPrice,
    required String newPrice,
    required String productUrl,
  }) async {
    // This would typically be called from your server

    if (kDebugMode) {
      print(
        '📤 FCM: Would send price alert for $productName: $oldPrice → $newPrice',
      );
    }
  }

  /// Subscribe to topic for general notifications
  Future<void> subscribeToTopic(String topic) async {
    if (_messaging == null || !_isInitialized) {
      if (kDebugMode) {
        print('❌ FCM: Not initialized, cannot subscribe to topic');
      }
      return;
    }

    try {
      await _messaging!.subscribeToTopic(topic);
      if (kDebugMode) {
        print('✅ FCM: Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to subscribe to topic $topic: $e');
      }
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (_messaging == null || !_isInitialized) return;

    try {
      await _messaging!.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        print('✅ FCM: Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to unsubscribe from topic $topic: $e');
      }
    }
  }

  /// Subscribe to notifications for a specific product
  Future<void> subscribeToProduct(String productId) async {
    await subscribeToTopic('product_$productId');
  }

  /// Unsubscribe from notifications for a specific product
  Future<void> unsubscribeFromProduct(String productId) async {
    await unsubscribeFromTopic('product_$productId');
  }

  /// Update FCM subscriptions based on user's favorite products
  Future<void> updateFavoriteSubscriptions() async {
    if (!_isInitialized) return;

    try {
      final favoriteIds =
          await DatabaseService.platformService.getFavoriteProductIds();

      // Subscribe to notifications for each favorite product
      for (final productId in favoriteIds) {
        await subscribeToProduct(productId);
      }

      if (kDebugMode) {
        print(
          '✅ FCM: Updated subscriptions for ${favoriteIds.length} favorite products',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to update favorite subscriptions: $e');
      }
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Check if FCM is initialized
  bool get isInitialized => _isInitialized;

  /// Refresh FCM token
  Future<void> refreshToken() async {
    if (_messaging == null) return;

    try {
      _fcmToken = await _messaging!.getToken();
      await _saveFCMToken();

      if (kDebugMode) {
        print('🔄 FCM: Token refreshed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to refresh token: $e');
      }
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already done
  // This ensures the handler can work when app is terminated

  if (kDebugMode) {
    print('📨 FCM: Background message received (app terminated)');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');
  }

  // Handle the message - you can show local notifications here
  // or perform other background tasks
}
