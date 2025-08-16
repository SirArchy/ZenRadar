// ignore_for_file: avoid_print

import '../models/website_stock_analytics.dart';
import '../models/stock_history.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/crawler_service.dart';

/// Service for fetching and analyzing website stock update patterns
class WebsiteAnalyticsService {
  static final WebsiteAnalyticsService _instance =
      WebsiteAnalyticsService._internal();
  factory WebsiteAnalyticsService() => _instance;
  WebsiteAnalyticsService._internal();

  static WebsiteAnalyticsService get instance => _instance;

  final DatabaseService _db = DatabaseService.instance;
  final CrawlerService _crawlerService = CrawlerService.instance;

  /// Get analytics for all websites based on current app mode
  Future<List<WebsiteStockAnalytics>> getAllWebsiteAnalytics({
    String timeRange = 'month',
  }) async {
    final settings = await SettingsService.instance.getSettings();

    if (settings.appMode == 'server') {
      // For now, use local analytics even in server mode
      // TODO: Implement Firestore analytics when needed
      return _getLocalWebsiteAnalytics(timeRange: timeRange);
    } else {
      return _getLocalWebsiteAnalytics(timeRange: timeRange);
    }
  }

  /// Get analytics from local SQLite database
  Future<List<WebsiteStockAnalytics>> _getLocalWebsiteAnalytics({
    String timeRange = 'month',
  }) async {
    final List<WebsiteStockAnalytics> analyticsData = [];

    // Get all available site keys from the crawler service
    final availableSites = _crawlerService.getAvailableSites();

    for (final siteKey in availableSites) {
      try {
        final siteName = _crawlerService.getSiteName(siteKey);

        // Get all products for this site
        final allProducts = await _db.getAllProducts();
        final siteProducts =
            allProducts
                .where(
                  (p) =>
                      p.site
                          .toLowerCase()
                          .replaceAll(' ', '')
                          .replaceAll('-', '') ==
                      siteName
                          .toLowerCase()
                          .replaceAll(' ', '')
                          .replaceAll('-', ''),
                )
                .toList();

        if (siteProducts.isEmpty) {
          // Add empty analytics for sites with no products
          analyticsData.add(
            WebsiteStockAnalytics(
              siteKey: siteKey,
              siteName: siteName,
              stockUpdates: [],
              totalProducts: 0,
              productsInStock: 0,
              productsOutOfStock: 0,
              stockPercentage: 0.0,
              recentUpdates: [],
              hourlyUpdatePattern: {},
              dailyUpdatePattern: {},
            ),
          );
          continue;
        }

        // Get stock history for all products from this site
        final List<StockHistory> allStockHistory = [];
        final Map<String, bool> currentProductStates = {};

        for (final product in siteProducts) {
          final productHistory = await _db.getStockHistoryForProduct(
            product.id,
          );

          // Filter by time range
          final DateTime cutoff;
          switch (timeRange) {
            case 'day':
              cutoff = DateTime.now().subtract(const Duration(days: 1));
              break;
            case 'week':
              cutoff = DateTime.now().subtract(const Duration(days: 7));
              break;
            case 'month':
              cutoff = DateTime.now().subtract(const Duration(days: 30));
              break;
            case 'all':
            default:
              cutoff = DateTime.fromMillisecondsSinceEpoch(0);
              break;
          }

          final filteredHistory =
              productHistory.where((h) => h.timestamp.isAfter(cutoff)).toList();
          allStockHistory.addAll(filteredHistory);
          currentProductStates[product.id] = product.isInStock;
        }

        // Create analytics for this website
        final analytics = WebsiteStockAnalytics.fromStockHistory(
          siteKey: siteKey,
          siteName: siteName,
          stockHistory: allStockHistory,
          currentProductStates: currentProductStates,
        );

        analyticsData.add(analytics);
      } catch (e) {
        print('Error getting analytics for $siteKey: $e');
        // Add empty analytics on error
        analyticsData.add(
          WebsiteStockAnalytics(
            siteKey: siteKey,
            siteName: _crawlerService.getSiteName(siteKey),
            stockUpdates: [],
            totalProducts: 0,
            productsInStock: 0,
            productsOutOfStock: 0,
            stockPercentage: 0.0,
            recentUpdates: [],
            hourlyUpdatePattern: {},
            dailyUpdatePattern: {},
          ),
        );
      }
    }

    return analyticsData;
  }

  /// Get analytics for a specific website
  Future<WebsiteStockAnalytics?> getWebsiteAnalytics(
    String siteKey, {
    String timeRange = 'month',
  }) async {
    final allAnalytics = await getAllWebsiteAnalytics(timeRange: timeRange);

    try {
      return allAnalytics.firstWhere(
        (analytics) => analytics.siteKey == siteKey,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get summary statistics across all websites
  Future<Map<String, dynamic>> getOverallSummary({
    String timeRange = 'month',
  }) async {
    final allAnalytics = await getAllWebsiteAnalytics(timeRange: timeRange);

    int totalWebsites = allAnalytics.length;
    int activeWebsites = allAnalytics.where((a) => a.totalProducts > 0).length;
    int totalProducts = allAnalytics.fold(0, (sum, a) => sum + a.totalProducts);
    int totalInStock = allAnalytics.fold(
      0,
      (sum, a) => sum + a.productsInStock,
    );
    int totalUpdates = allAnalytics.fold(
      0,
      (sum, a) => sum + a.stockUpdates.length,
    );

    double overallStockPercentage =
        totalProducts > 0 ? (totalInStock / totalProducts) * 100 : 0.0;

    // Find most active website
    WebsiteStockAnalytics? mostActiveWebsite;
    int maxUpdates = 0;
    for (final analytics in allAnalytics) {
      if (analytics.stockUpdates.length > maxUpdates) {
        maxUpdates = analytics.stockUpdates.length;
        mostActiveWebsite = analytics;
      }
    }

    // Find most recent update
    DateTime? mostRecentUpdate;
    for (final analytics in allAnalytics) {
      if (analytics.lastStockChange != null) {
        if (mostRecentUpdate == null ||
            analytics.lastStockChange!.isAfter(mostRecentUpdate)) {
          mostRecentUpdate = analytics.lastStockChange;
        }
      }
    }

    return {
      'totalWebsites': totalWebsites,
      'activeWebsites': activeWebsites,
      'totalProducts': totalProducts,
      'totalInStock': totalInStock,
      'overallStockPercentage': overallStockPercentage,
      'totalUpdates': totalUpdates,
      'mostActiveWebsite': mostActiveWebsite?.siteName,
      'mostRecentUpdate': mostRecentUpdate,
    };
  }
}
