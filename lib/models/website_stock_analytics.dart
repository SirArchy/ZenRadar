import 'package:intl/intl.dart';
import 'stock_history.dart';

/// Analytics data for a single website showing stock change patterns
class WebsiteStockAnalytics {
  final String siteKey;
  final String siteName;
  final List<StockStatusPoint> stockUpdates;
  final int totalProducts;
  final int productsInStock;
  final int productsOutOfStock;
  final double stockPercentage;
  final DateTime? lastStockChange;
  final List<StockUpdateEvent> recentUpdates;
  final Map<int, int> hourlyUpdatePattern; // Hour -> number of updates
  final Map<String, int> dailyUpdatePattern; // Date -> number of updates

  WebsiteStockAnalytics({
    required this.siteKey,
    required this.siteName,
    required this.stockUpdates,
    required this.totalProducts,
    required this.productsInStock,
    required this.productsOutOfStock,
    required this.stockPercentage,
    this.lastStockChange,
    required this.recentUpdates,
    required this.hourlyUpdatePattern,
    required this.dailyUpdatePattern,
  });

  /// Create analytics from raw stock history data
  factory WebsiteStockAnalytics.fromStockHistory({
    required String siteKey,
    required String siteName,
    required List<StockHistory> stockHistory,
    required Map<String, bool> currentProductStates,
  }) {
    final totalProducts = currentProductStates.length;
    final productsInStock =
        currentProductStates.values.where((inStock) => inStock).length;
    final productsOutOfStock = totalProducts - productsInStock;
    final stockPercentage =
        totalProducts > 0 ? (productsInStock / totalProducts) * 100 : 0.0;

    // Group stock history by timestamp to find update events
    final Map<String, List<StockHistory>> groupedHistory = {};
    for (final history in stockHistory) {
      final timeKey = DateFormat('yyyy-MM-dd HH:mm').format(history.timestamp);
      groupedHistory.putIfAbsent(timeKey, () => []).add(history);
    }

    // Create stock status points showing when updates happened
    final stockUpdates = <StockStatusPoint>[];
    final recentUpdates = <StockUpdateEvent>[];
    final hourlyPattern = <int, int>{};
    final dailyPattern = <String, int>{};

    DateTime? lastStockChange;

    for (final entry in groupedHistory.entries) {
      final timestamp = DateFormat('yyyy-MM-dd HH:mm').parse(entry.key);
      final changes = entry.value;

      // Count products that changed to in-stock vs out-of-stock
      int inStockChanges = 0;
      int outOfStockChanges = 0;

      for (final change in changes) {
        if (change.isInStock) {
          inStockChanges++;
        } else {
          outOfStockChanges++;
        }
      }

      if (changes.isNotEmpty) {
        lastStockChange = timestamp;

        // Add to hourly pattern
        final hour = timestamp.hour;
        hourlyPattern[hour] = (hourlyPattern[hour] ?? 0) + changes.length;

        // Add to daily pattern
        final dayKey = DateFormat('yyyy-MM-dd').format(timestamp);
        dailyPattern[dayKey] = (dailyPattern[dayKey] ?? 0) + changes.length;

        // Create stock status point
        stockUpdates.add(
          StockStatusPoint(
            timestamp: timestamp,
            isInStock: inStockChanges > outOfStockChanges,
            stockDuration: changes.length, // Use as update count
          ),
        );

        // Add recent updates (last 7 days)
        final isRecent = DateTime.now().difference(timestamp).inDays <= 7;
        if (isRecent) {
          recentUpdates.add(
            StockUpdateEvent(
              timestamp: timestamp,
              productsRestocked: inStockChanges,
              productsOutOfStock: outOfStockChanges,
              totalUpdates: changes.length,
            ),
          );
        }
      }
    }

    // Sort updates by timestamp
    stockUpdates.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    recentUpdates.sort(
      (a, b) => b.timestamp.compareTo(a.timestamp),
    ); // Most recent first

    return WebsiteStockAnalytics(
      siteKey: siteKey,
      siteName: siteName,
      stockUpdates: stockUpdates,
      totalProducts: totalProducts,
      productsInStock: productsInStock,
      productsOutOfStock: productsOutOfStock,
      stockPercentage: stockPercentage,
      lastStockChange: lastStockChange,
      recentUpdates: recentUpdates,
      hourlyUpdatePattern: hourlyPattern,
      dailyUpdatePattern: dailyPattern,
    );
  }

  /// Get stock updates filtered by time range
  List<StockStatusPoint> getFilteredUpdates(String timeRange) {
    final now = DateTime.now();
    DateTime cutoff;

    switch (timeRange) {
      case 'day':
        cutoff = now.subtract(const Duration(days: 1));
        break;
      case 'week':
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        cutoff = now.subtract(const Duration(days: 30));
        break;
      case 'all':
      default:
        return stockUpdates;
    }

    return stockUpdates
        .where((update) => update.timestamp.isAfter(cutoff))
        .toList();
  }

  /// Get the most active hour for stock updates
  int? get mostActiveHour {
    if (hourlyUpdatePattern.isEmpty) return null;

    int maxHour = 0;
    int maxUpdates = 0;

    for (final entry in hourlyUpdatePattern.entries) {
      if (entry.value > maxUpdates) {
        maxUpdates = entry.value;
        maxHour = entry.key;
      }
    }

    return maxHour;
  }

  /// Get update frequency description
  String get updateFrequencyDescription {
    if (stockUpdates.isEmpty) return 'No updates recorded';

    final totalDays =
        DateTime.now().difference(stockUpdates.first.timestamp).inDays;
    if (totalDays == 0) return 'New site';

    final updatesPerDay = stockUpdates.length / totalDays;

    if (updatesPerDay >= 5) return 'Very frequent updates';
    if (updatesPerDay >= 2) return 'Regular updates';
    if (updatesPerDay >= 0.5) return 'Occasional updates';
    return 'Rare updates';
  }
}

/// Represents a stock update event at a specific time
class StockUpdateEvent {
  final DateTime timestamp;
  final int productsRestocked;
  final int productsOutOfStock;
  final int totalUpdates;

  StockUpdateEvent({
    required this.timestamp,
    required this.productsRestocked,
    required this.productsOutOfStock,
    required this.totalUpdates,
  });

  bool get hasRestocks => productsRestocked > 0;
  bool get hasOutOfStock => productsOutOfStock > 0;

  String get description {
    if (hasRestocks && hasOutOfStock) {
      return '$productsRestocked restocked, $productsOutOfStock out of stock';
    } else if (hasRestocks) {
      return '$productsRestocked products restocked';
    } else if (hasOutOfStock) {
      return '$productsOutOfStock products out of stock';
    } else {
      return '$totalUpdates products updated';
    }
  }
}
