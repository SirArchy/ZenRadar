// ignore_for_file: avoid_print

import 'dart:async';
import '../models/website_stock_analytics.dart';
import '../models/matcha_product.dart';
import '../models/stock_history.dart';
import '../services/settings_service.dart';
import '../services/firestore_service.dart';
import '../services/database_service.dart';
import '../services/cache_service.dart';

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
    bool forceRefresh = false,
  }) async {
    return await getWebsiteAnalytics(
      timeRange: timeRange,
      forceRefresh: forceRefresh,
    );
  }

  /// Get a fast summary that loads quicker than full analytics (for initial screen load)
  Future<Map<String, dynamic>> getFastSummary({
    required String timeRange,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'fast_summary_$timeRange';

    // Try to get from cache first unless force refresh is requested
    if (!forceRefresh) {
      final cachedSummary = await CacheService.getCache<Map<String, dynamic>>(
        cacheKey,
      );
      if (cachedSummary != null) {
        print('Using cached fast summary for $timeRange');
        return cachedSummary;
      }
    }

    try {
      // Check if server mode is enabled
      bool isServerMode = await _settingsService.getServerMode();
      Map<String, dynamic> summary;

      if (isServerMode) {
        // For server mode, use existing method
        summary = await getAnalyticsSummary(
          timeRange: timeRange,
          forceRefresh: forceRefresh,
        );
      } else {
        // For local mode, create a lightweight summary without full processing
        summary = await _getFastLocalSummary(timeRange: timeRange);
      }

      // Cache the results for 5 minutes (shorter than full analytics)
      await CacheService.setCache(
        cacheKey,
        summary,
        duration: const Duration(minutes: 5),
      );

      return summary;
    } catch (e) {
      print('Error getting fast summary: $e');
      return {};
    }
  }

  /// Create a lightweight summary for local mode without full processing
  Future<Map<String, dynamic>> _getFastLocalSummary({
    required String timeRange,
  }) async {
    // This is a simplified version that provides basic data quickly
    return {
      'totalProducts': 0,
      'totalInStock': 0,
      'totalOutOfStock': 0,
      'totalUpdates': 0,
      'stockPercentage': 0.0,
      'mostRecentUpdate': null,
      'recentUpdates': <Map<String, dynamic>>[],
    };
  }

  /// Get analytics data for all websites (internal method)
  Future<List<WebsiteStockAnalytics>> getWebsiteAnalytics({
    required String timeRange,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'website_analytics_$timeRange';

    // Try to get from cache first unless force refresh is requested
    if (!forceRefresh) {
      final cachedAnalytics = await CacheService.getCache<List<dynamic>>(
        cacheKey,
      );
      if (cachedAnalytics != null) {
        print('Using cached website analytics for $timeRange');
        return cachedAnalytics
            .map(
              (item) =>
                  WebsiteStockAnalytics.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    }

    try {
      List<WebsiteStockAnalytics> analytics;

      // Check if server mode is enabled
      bool isServerMode = await _settingsService.getServerMode();

      if (isServerMode) {
        analytics = await _getFirestoreWebsiteAnalytics(timeRange: timeRange);
      } else {
        analytics = await _getLocalWebsiteAnalytics(timeRange: timeRange);
      }

      // Cache the results for 15 minutes
      await CacheService.setCache(
        cacheKey,
        analytics.map((item) => item.toJson()).toList(),
        duration: const Duration(minutes: 15),
      );

      print(
        'Cached website analytics for $timeRange (${analytics.length} sites)',
      );
      return analytics;
    } catch (e) {
      print('Error getting website analytics: $e');
      return [];
    }
  }

  /// Get analytics summary across all websites (public method)
  Future<Map<String, dynamic>> getOverallSummary({
    required String timeRange,
    bool forceRefresh = false,
  }) async {
    return await getAnalyticsSummary(
      timeRange: timeRange,
      forceRefresh: forceRefresh,
    );
  }

  /// Get analytics summary across all websites (internal method)
  Future<Map<String, dynamic>> getAnalyticsSummary({
    required String timeRange,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'analytics_summary_$timeRange';

    // Try to get from cache first unless force refresh is requested
    if (!forceRefresh) {
      final cachedSummary = await CacheService.getCache<Map<String, dynamic>>(
        cacheKey,
      );
      if (cachedSummary != null) {
        print('Using cached analytics summary for $timeRange');
        // Convert string dates back to DateTime objects
        final result = Map<String, dynamic>.from(cachedSummary);
        if (result['mostRecentUpdate'] != null) {
          result['mostRecentUpdate'] = DateTime.parse(
            result['mostRecentUpdate'] as String,
          );
        }
        if (result['lastUpdated'] != null) {
          result['lastUpdated'] = DateTime.parse(
            result['lastUpdated'] as String,
          );
        }
        return result;
      }
    }

    try {
      final analytics = await getWebsiteAnalytics(
        timeRange: timeRange,
        forceRefresh: forceRefresh,
      );

      int totalProducts = 0;
      int totalInStock = 0;
      int totalOutOfStock = 0;
      int totalUpdates = 0;
      int activeWebsites = 0;
      DateTime? mostRecentUpdate;
      String? mostActiveWebsite;
      int maxUpdates = 0;

      for (final website in analytics) {
        totalProducts += website.totalProducts;
        totalInStock += website.productsInStock;
        totalOutOfStock += website.productsOutOfStock;
        totalUpdates += website.recentUpdates.length;

        if (website.totalProducts > 0) {
          activeWebsites++;
        }

        // Find most recent update
        if (website.lastStockChange != null) {
          if (mostRecentUpdate == null ||
              website.lastStockChange!.isAfter(mostRecentUpdate)) {
            mostRecentUpdate = website.lastStockChange;
          }
        }

        // Find most active website
        if (website.recentUpdates.length > maxUpdates) {
          maxUpdates = website.recentUpdates.length;
          mostActiveWebsite = website.siteName;
        }
      }

      double overallStockPercentage = 0.0;
      if (totalProducts > 0) {
        overallStockPercentage = (totalInStock / totalProducts) * 100;
      }

      final summary = {
        'totalWebsites': analytics.length,
        'activeWebsites': activeWebsites,
        'totalProducts': totalProducts,
        'totalInStock': totalInStock,
        'totalOutOfStock': totalOutOfStock,
        'overallStockPercentage': overallStockPercentage,
        'totalUpdates': totalUpdates,
        'mostRecentUpdate': mostRecentUpdate?.toIso8601String(),
        'mostActiveWebsite': mostActiveWebsite,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      // Cache the results for 15 minutes
      await CacheService.setCache(
        cacheKey,
        summary,
        duration: const Duration(minutes: 15),
      );

      print('Cached analytics summary for $timeRange');
      return summary;
    } catch (e) {
      print('Error getting analytics summary: $e');
      return {
        'totalWebsites': 0,
        'activeWebsites': 0,
        'totalProducts': 0,
        'totalInStock': 0,
        'totalOutOfStock': 0,
        'overallStockPercentage': 0.0,
        'totalUpdates': 0,
        'mostRecentUpdate': null,
        'mostActiveWebsite': null,
        'lastUpdated': DateTime.now(),
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

  /// Get local analytics (local mode)
  Future<List<WebsiteStockAnalytics>> _getLocalWebsiteAnalytics({
    required String timeRange,
  }) async {
    List<WebsiteStockAnalytics> websiteAnalytics = [];

    try {
      // Use the DatabaseService singleton for local database access
      final DatabaseService dbService = DatabaseService.instance;

      for (String siteName in supportedWebsites) {
        // Get products for this site
        List<MatchaProduct> products = await dbService.getProductsBySite(
          siteName,
        );

        // Get stock history for analysis
        List<StockHistory> stockHistory = await dbService
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
      print('Error getting local website analytics: $e');
    }

    return websiteAnalytics;
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
        // Local mode - get data from local database
        final DatabaseService dbService = DatabaseService.instance;
        for (String siteName in supportedWebsites) {
          List<StockHistory> history = await dbService.getStockHistoryForSite(
            siteName,
            _getCutoffDate(timeRange),
            DateTime.now(),
          );

          trends[siteName] = _processStockTrendsData(history, timeRange);
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
