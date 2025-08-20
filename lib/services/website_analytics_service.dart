// ignore_for_file: avoid_print

import 'dart:async';
import '../models/website_stock_analytics.dart';
import '../models/matcha_product.dart';
import '../models/stock_history.dart';
import '../services/settings_service.dart';
import '../services/firestore_service.dart';

class WebsiteAnalyticsService {
  static final WebsiteAnalyticsService _instance =
      WebsiteAnalyticsService._internal();
  static WebsiteAnalyticsService get instance => _instance;

  WebsiteAnalyticsService._internal();

  final SettingsService _settingsService = SettingsService();
  final FirestoreService _firestoreService = FirestoreService();

  // Supported websites
  static const List<String> supportedWebsites = [
    'tokichi',
    'marukyu',
    'ippodo',
    'horrimeicha',
    'yoshien',
    'matcha-karu',
    'sho-cha',
    'sazentea',
    'enjoyemeri',
    'poppatea',
    'horiishichimeien',
  ];

  /// Get analytics data for all websites
  Future<List<WebsiteStockAnalytics>> getAllWebsiteAnalytics({
    required String timeRange,
  }) async {
    return await getWebsiteAnalytics(timeRange: timeRange);
  }

  /// Get analytics data for all websites (internal method)
  Future<List<WebsiteStockAnalytics>> getWebsiteAnalytics({
    required String timeRange,
  }) async {
    try {
      // Check if server mode is enabled
      bool isServerMode = await _settingsService.getServerMode();

      if (isServerMode) {
        return await _getFirestoreWebsiteAnalytics(timeRange: timeRange);
      } else {
        return await _getLocalWebsiteAnalytics(timeRange: timeRange);
      }
    } catch (e) {
      print('Error getting website analytics: $e');
      return [];
    }
  }

  /// Get analytics summary across all websites (public method)
  Future<Map<String, dynamic>> getOverallSummary({
    required String timeRange,
  }) async {
    return await getAnalyticsSummary(timeRange: timeRange);
  }

  /// Get analytics summary across all websites (internal method)
  Future<Map<String, dynamic>> getAnalyticsSummary({
    required String timeRange,
  }) async {
    try {
      final analytics = await getWebsiteAnalytics(timeRange: timeRange);

      int totalProducts = 0;
      int totalInStock = 0;
      int totalOutOfStock = 0;
      double totalStockPercentage = 0.0;

      for (final website in analytics) {
        totalProducts += website.totalProducts;
        totalInStock += website.productsInStock;
        totalOutOfStock += website.productsOutOfStock;
      }

      if (analytics.isNotEmpty && totalProducts > 0) {
        totalStockPercentage = (totalInStock / totalProducts) * 100;
      }

      return {
        'totalWebsites': analytics.length,
        'totalProducts': totalProducts,
        'totalInStock': totalInStock,
        'totalOutOfStock': totalOutOfStock,
        'averageStockPercentage': totalStockPercentage,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error getting analytics summary: $e');
      return {
        'totalWebsites': 0,
        'totalProducts': 0,
        'totalInStock': 0,
        'totalOutOfStock': 0,
        'averageStockPercentage': 0.0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get Firestore-based analytics (server mode)
  Future<List<WebsiteStockAnalytics>> _getFirestoreWebsiteAnalytics({
    required String timeRange,
  }) async {
    List<WebsiteStockAnalytics> websiteAnalytics = [];

    try {
      for (String siteName in supportedWebsites) {
        // Get products for this site
        List<MatchaProduct> products = await _firestoreService
            .getProductsBySite(siteName);

        // Get stock history for analysis
        List<StockHistory> stockHistory = await _firestoreService
            .getStockHistoryForSite(
              siteName,
              _getCutoffDate(timeRange),
              DateTime.now(),
            );

        // Create current product states map
        Map<String, bool> currentProductStates = {};
        for (MatchaProduct product in products) {
          currentProductStates[product.id] = product.isInStock;
        }

        // Create analytics using the factory method
        WebsiteStockAnalytics analytics =
            WebsiteStockAnalytics.fromStockHistory(
              siteKey: siteName,
              siteName: _getDisplayName(siteName),
              stockHistory: stockHistory,
              currentProductStates: currentProductStates,
            );

        websiteAnalytics.add(analytics);
      }
    } catch (e) {
      print('Error getting Firestore website analytics: $e');
    }

    return websiteAnalytics;
  }

  /// Get local analytics (local mode - placeholder)
  Future<List<WebsiteStockAnalytics>> _getLocalWebsiteAnalytics({
    required String timeRange,
  }) async {
    // For local mode, we would read from local database
    // For now, return empty list or mock data
    return [];
  }

  /// Get cutoff date based on time range
  DateTime _getCutoffDate(String timeRange) {
    DateTime now = DateTime.now();

    switch (timeRange.toLowerCase()) {
      case 'day':
        return now.subtract(const Duration(days: 1));
      case 'week':
        return now.subtract(const Duration(days: 7));
      case 'month':
        return now.subtract(const Duration(days: 30));
      case 'year':
        return now.subtract(const Duration(days: 365));
      default:
        return now.subtract(const Duration(days: 30)); // Default to month
    }
  }

  /// Get display name for website
  String _getDisplayName(String siteName) {
    switch (siteName.toLowerCase()) {
      case 'tokichi':
        return 'Nakamura Tokichi';
      case 'ippodo':
        return 'Ippodo Tea';
      case 'marukyu':
        return 'Marukyu-Koyamaen';
      case 'horrimeicha':
        return 'Horrimeicha';
      case 'yoshien':
        return 'Yoshi En';
      case 'matcha-karu':
        return 'Matcha Kāru';
      case 'sho-cha':
        return 'Sho-Cha';
      case 'sazentea':
        return 'Sazen Tea';
      case 'enjoyemeri':
        return 'Enjoy Emeri';
      case 'poppatea':
        return 'Poppa Tea';
      case 'horiishichimeien':
        return 'Hori Shichimeien';
      default:
        return siteName.toUpperCase();
    }
  }

  /// Get website stock trends for charting
  Future<Map<String, List<Map<String, dynamic>>>> getWebsiteStockTrends({
    required String timeRange,
  }) async {
    Map<String, List<Map<String, dynamic>>> trends = {};

    try {
      bool isServerMode = await _settingsService.getServerMode();

      if (isServerMode) {
        for (String siteName in supportedWebsites) {
          List<StockHistory> history = await _firestoreService
              .getStockHistoryForSite(
                siteName,
                _getCutoffDate(timeRange),
                DateTime.now(),
              );

          trends[siteName] = _processStockTrendsData(history, timeRange);
        }
      } else {
        // Local mode - return empty or mock data
        for (String siteName in supportedWebsites) {
          trends[siteName] = [];
        }
      }
    } catch (e) {
      print('Error getting website stock trends: $e');
    }

    return trends;
  }

  /// Process stock history into trend data for charting
  List<Map<String, dynamic>> _processStockTrendsData(
    List<StockHistory> history,
    String timeRange,
  ) {
    if (history.isEmpty) return [];

    // Group by day/hour depending on time range
    Map<String, Map<String, int>> groupedData = {};

    for (StockHistory entry in history) {
      String key = _getTimeKey(entry.timestamp, timeRange);

      if (!groupedData.containsKey(key)) {
        groupedData[key] = {'inStock': 0, 'outOfStock': 0};
      }

      if (entry.isInStock) {
        groupedData[key]!['inStock'] = groupedData[key]!['inStock']! + 1;
      } else {
        groupedData[key]!['outOfStock'] = groupedData[key]!['outOfStock']! + 1;
      }
    }

    // Convert to chart data format
    List<Map<String, dynamic>> chartData = [];
    List<String> sortedKeys = groupedData.keys.toList()..sort();

    for (String key in sortedKeys) {
      chartData.add({
        'time': key,
        'inStock': groupedData[key]!['inStock'],
        'outOfStock': groupedData[key]!['outOfStock'],
        'total':
            groupedData[key]!['inStock']! + groupedData[key]!['outOfStock']!,
      });
    }

    return chartData;
  }

  /// Get time key for grouping data
  String _getTimeKey(DateTime timestamp, String timeRange) {
    switch (timeRange.toLowerCase()) {
      case 'day':
        return '${timestamp.hour}:00';
      case 'week':
        return '${timestamp.month}/${timestamp.day}';
      case 'month':
        return '${timestamp.month}/${timestamp.day}';
      case 'year':
        return '${timestamp.year}/${timestamp.month}';
      default:
        return '${timestamp.month}/${timestamp.day}';
    }
  }
}
