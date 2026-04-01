// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:zenradar/models/matcha_product.dart';
import 'package:zenradar/data/services/data/database_service.dart';
import 'package:zenradar/data/services/notifications/notification_service.dart';
import 'package:zenradar/data/services/settings/settings_service.dart';

/// Service to handle notifications for favorite products
/// Works in server mode by listening to Firestore changes
class FavoriteNotificationService {
  static final FavoriteNotificationService _instance =
      FavoriteNotificationService._internal();
  factory FavoriteNotificationService() => _instance;
  FavoriteNotificationService._internal();

  static FavoriteNotificationService get instance => _instance;

  bool _isListening = false;
  final Map<String, MatchaProduct> _lastKnownState = {};

  /// Initialize the service and start monitoring favorite products
  Future<void> initializeService() async {
    if (_isListening) {
      if (kDebugMode) {
        print('🔔 Favorite notification service already running');
      }
      return;
    }

    try {
      final settings = await SettingsService.instance.getSettings();

      if (!settings.notificationsEnabled ||
          !settings.favoriteProductNotifications) {
        if (kDebugMode) {
          print('🔕 Favorite notifications disabled in settings');
        }
        return;
      }

      await _startMonitoring();
      _isListening = true;

      // FCM subscriptions are already handled by BackendService.initializeFCM()
      // No need to call updateFavoriteSubscriptions() again here

      if (kDebugMode) {
        print('🔔 Favorite notification service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize favorite notification service: $e');
      }
    }
  }

  /// Stop monitoring favorite products
  Future<void> stopService() async {
    _isListening = false;
    _lastKnownState.clear();

    if (kDebugMode) {
      print('🔕 Favorite notification service stopped');
    }
  }

  /// Start monitoring favorite products for changes
  Future<void> _startMonitoring() async {
    try {
      // Load initial state of favorite products
      await _loadInitialState();

      // In server mode, we would listen to Firestore changes
      // For now, we'll implement a periodic check
      _startPeriodicCheck();

      if (kDebugMode) {
        print(
          '🔔 Started monitoring ${_lastKnownState.length} favorite products',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to start monitoring: $e');
      }
    }
  }

  /// Load the initial state of all favorite products
  Future<void> _loadInitialState() async {
    try {
      final favorites =
          await DatabaseService.platformService.getFavoriteProducts();

      for (final product in favorites) {
        _lastKnownState[product.id] = product;
      }

      if (kDebugMode) {
        print(
          '📊 Loaded initial state for ${favorites.length} favorite products',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to load initial state: $e');
      }
    }
  }

  /// Start periodic checking for changes (fallback for server mode)
  void _startPeriodicCheck() {
    // Check every 5 minutes for changes
    Stream.periodic(const Duration(minutes: 5)).listen((_) async {
      if (_isListening) {
        await _checkForChanges();
      }
    });
  }

  /// Check for changes in favorite products
  Future<void> _checkForChanges() async {
    try {
      final settings = await SettingsService.instance.getSettings();

      if (!settings.notificationsEnabled ||
          !settings.favoriteProductNotifications) {
        return;
      }

      final currentFavorites =
          await DatabaseService.platformService.getFavoriteProducts();

      for (final currentProduct in currentFavorites) {
        final lastKnownProduct = _lastKnownState[currentProduct.id];

        if (lastKnownProduct != null) {
          await _compareAndNotify(lastKnownProduct, currentProduct, settings);
        }

        // Update the known state
        _lastKnownState[currentProduct.id] = currentProduct;
      }

      if (kDebugMode) {
        print(
          '🔍 Checked ${currentFavorites.length} favorite products for changes',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to check for changes: $e');
      }
    }
  }

  /// Compare products and send notifications if needed
  Future<void> _compareAndNotify(
    MatchaProduct oldProduct,
    MatchaProduct newProduct,
    UserSettings settings,
  ) async {
    try {
      // Check for stock changes
      if (settings.notifyStockChanges &&
          _hasStockChanged(oldProduct, newProduct)) {
        await _sendStockChangeNotification(newProduct);
      }

      // Check for price changes
      if (settings.notifyPriceChanges &&
          _hasPriceChanged(oldProduct, newProduct)) {
        await _sendPriceChangeNotification(oldProduct, newProduct);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to send notification for ${newProduct.name}: $e');
      }
    }
  }

  /// Check if stock status has changed (specifically back in stock)
  bool _hasStockChanged(MatchaProduct oldProduct, MatchaProduct newProduct) {
    // Only notify when product comes back in stock
    return !oldProduct.isInStock && newProduct.isInStock;
  }

  /// Check if price has changed significantly
  bool _hasPriceChanged(MatchaProduct oldProduct, MatchaProduct newProduct) {
    if (oldProduct.priceValue == null || newProduct.priceValue == null) {
      return false;
    }

    // Notify if price changed by more than 1%
    final oldPrice = oldProduct.priceValue!;
    final newPrice = newProduct.priceValue!;
    final changePercent = ((newPrice - oldPrice) / oldPrice).abs();

    return changePercent > 0.01; // 1% threshold
  }

  /// Send stock change notification
  Future<void> _sendStockChangeNotification(MatchaProduct product) async {
    try {
      await NotificationService.instance.showStockAlert(
        productName: product.name,
        siteName: product.site,
        productId: product.id,
        productUrl: product.url,
      );

      if (kDebugMode) {
        print('📬 Sent stock notification for ${product.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to send stock notification: $e');
      }
    }
  }

  /// Send price change notification
  Future<void> _sendPriceChangeNotification(
    MatchaProduct oldProduct,
    MatchaProduct newProduct,
  ) async {
    try {
      final oldPrice =
          oldProduct.priceValue?.toStringAsFixed(2) ??
          oldProduct.price ??
          'N/A';
      final newPrice =
          newProduct.priceValue?.toStringAsFixed(2) ??
          newProduct.price ??
          'N/A';
      final priceDirection =
          (newProduct.priceValue ?? 0) > (oldProduct.priceValue ?? 0)
              ? '📈'
              : '📉';

      await NotificationService.instance.showNotification(
        id:
            newProduct.id.hashCode +
            1000, // Different ID for price notifications
        title: '$priceDirection Price Change: ${newProduct.name}',
        body: 'Price changed from $oldPrice to $newPrice on ${newProduct.site}',
        payload: newProduct.url,
      );

      if (kDebugMode) {
        print(
          '💰 Sent price notification for ${newProduct.name}: $oldPrice → $newPrice',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to send price notification: $e');
      }
    }
  }

  /// Manually trigger a check for all favorite products
  Future<void> manualCheck() async {
    if (kDebugMode) {
      print('🔍 Manual check triggered for favorite products');
    }
    await _checkForChanges();
  }

  /// Update service settings when user changes notification preferences
  Future<void> updateSettings() async {
    final settings = await SettingsService.instance.getSettings();

    if (!settings.notificationsEnabled ||
        !settings.favoriteProductNotifications) {
      if (_isListening) {
        await stopService();
      }
    } else if (!_isListening) {
      await initializeService();
    }

    if (kDebugMode) {
      print('⚙️ Updated favorite notification service settings');
    }
  }

  /// Get current monitoring status
  bool get isMonitoring => _isListening;

  /// Get number of favorite products being monitored
  int get monitoredProductsCount => _lastKnownState.length;
}
