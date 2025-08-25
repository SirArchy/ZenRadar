import 'package:intl/intl.dart';

class StockHistory {
  final int? id;
  final String productId;
  final bool isInStock;
  final DateTime timestamp;

  StockHistory({
    this.id,
    required this.productId,
    required this.isInStock,
    required this.timestamp,
  });

  factory StockHistory.fromJson(Map<String, dynamic> json) {
    return StockHistory(
      id: json['id'],
      productId: json['productId'],
      isInStock: json['isInStock'] == 1,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'productId': productId,
      'isInStock': isInStock ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Helper to create an hourly key for grouping
  String get hourlyKey {
    return DateFormat('yyyy-MM-dd HH:00').format(timestamp);
  }

  // Helper to create a daily key for grouping
  String get dailyKey {
    return DateFormat('yyyy-MM-dd').format(timestamp);
  }
}

class StockStatusPoint {
  final DateTime timestamp;
  final bool isInStock;
  final int stockDuration; // Duration in minutes this status was maintained

  StockStatusPoint({
    required this.timestamp,
    required this.isInStock,
    this.stockDuration = 0,
  });

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'isInStock': isInStock,
      'stockDuration': stockDuration,
    };
  }

  /// Create from JSON for caching
  factory StockStatusPoint.fromJson(Map<String, dynamic> json) {
    return StockStatusPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      isInStock: json['isInStock'] as bool,
      stockDuration: json['stockDuration'] as int,
    );
  }
}

class StockAnalytics {
  final List<StockHistory> stockHistory;
  final int totalChecks;
  final int inStockCount;
  final int outOfStockCount;
  final double availabilityPercentage;
  final DateTime? lastInStock;
  final DateTime? lastOutOfStock;
  final Duration? averageStockDuration;
  final Duration? averageOutOfStockDuration;
  final List<StockStatusPoint> statusPoints;

  StockAnalytics({
    required this.stockHistory,
    required this.totalChecks,
    required this.inStockCount,
    required this.outOfStockCount,
    required this.availabilityPercentage,
    this.lastInStock,
    this.lastOutOfStock,
    this.averageStockDuration,
    this.averageOutOfStockDuration,
    required this.statusPoints,
  });

  factory StockAnalytics.fromHistory(List<StockHistory> history) {
    if (history.isEmpty) {
      return StockAnalytics(
        stockHistory: [],
        totalChecks: 0,
        inStockCount: 0,
        outOfStockCount: 0,
        availabilityPercentage: 0.0,
        statusPoints: [],
      );
    }

    // Sort by timestamp
    final sortedHistory = List<StockHistory>.from(history)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final totalChecks = sortedHistory.length;
    final inStockCount = sortedHistory.where((h) => h.isInStock).length;
    final outOfStockCount = totalChecks - inStockCount;
    final availabilityPercentage =
        totalChecks > 0 ? (inStockCount / totalChecks) * 100 : 0.0;

    // Find last occurrences
    DateTime? lastInStock;
    DateTime? lastOutOfStock;

    for (final entry in sortedHistory.reversed) {
      if (lastInStock == null && entry.isInStock) {
        lastInStock = entry.timestamp;
      }
      if (lastOutOfStock == null && !entry.isInStock) {
        lastOutOfStock = entry.timestamp;
      }
      if (lastInStock != null && lastOutOfStock != null) break;
    }

    // Calculate status points with durations
    final statusPoints = <StockStatusPoint>[];
    for (int i = 0; i < sortedHistory.length; i++) {
      final current = sortedHistory[i];
      int duration = 0;

      if (i < sortedHistory.length - 1) {
        final next = sortedHistory[i + 1];
        duration = next.timestamp.difference(current.timestamp).inMinutes;
      }

      statusPoints.add(
        StockStatusPoint(
          timestamp: current.timestamp,
          isInStock: current.isInStock,
          stockDuration: duration,
        ),
      );
    }

    // Calculate average durations
    Duration? averageStockDuration;
    Duration? averageOutOfStockDuration;

    final stockDurations = <int>[];
    final outOfStockDurations = <int>[];

    for (final point in statusPoints) {
      if (point.stockDuration > 0) {
        if (point.isInStock) {
          stockDurations.add(point.stockDuration);
        } else {
          outOfStockDurations.add(point.stockDuration);
        }
      }
    }

    if (stockDurations.isNotEmpty) {
      final avgMinutes =
          stockDurations.reduce((a, b) => a + b) / stockDurations.length;
      averageStockDuration = Duration(minutes: avgMinutes.round());
    }

    if (outOfStockDurations.isNotEmpty) {
      final avgMinutes =
          outOfStockDurations.reduce((a, b) => a + b) /
          outOfStockDurations.length;
      averageOutOfStockDuration = Duration(minutes: avgMinutes.round());
    }

    return StockAnalytics(
      stockHistory: sortedHistory,
      totalChecks: totalChecks,
      inStockCount: inStockCount,
      outOfStockCount: outOfStockCount,
      availabilityPercentage: availabilityPercentage,
      lastInStock: lastInStock,
      lastOutOfStock: lastOutOfStock,
      averageStockDuration: averageStockDuration,
      averageOutOfStockDuration: averageOutOfStockDuration,
      statusPoints: statusPoints,
    );
  }

  // Get stock history aggregated by hour
  List<StockStatusPoint> get hourlyAggregatedHistory {
    final Map<String, StockStatusPoint> hourlyPoints = {};

    for (final entry in stockHistory) {
      final hourKey = entry.hourlyKey;

      // Use the latest status within each hour
      if (!hourlyPoints.containsKey(hourKey) ||
          entry.timestamp.isAfter(hourlyPoints[hourKey]!.timestamp)) {
        hourlyPoints[hourKey] = StockStatusPoint(
          timestamp: entry.timestamp,
          isInStock: entry.isInStock,
        );
      }
    }

    final result =
        hourlyPoints.values.toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return result;
  }

  // Get stock history for a specific day with hourly granularity
  List<StockStatusPoint> getHourlyHistoryForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final dayHistory =
        stockHistory
            .where(
              (h) =>
                  h.timestamp.isAfter(dayStart) && h.timestamp.isBefore(dayEnd),
            )
            .toList();

    if (dayHistory.isEmpty) return [];

    // Group by hour and take the latest status in each hour
    final Map<int, StockStatusPoint> hourlyPoints = {};

    for (final entry in dayHistory) {
      final hour = entry.timestamp.hour;

      if (!hourlyPoints.containsKey(hour) ||
          entry.timestamp.isAfter(hourlyPoints[hour]!.timestamp)) {
        hourlyPoints[hour] = StockStatusPoint(
          timestamp: entry.timestamp,
          isInStock: entry.isInStock,
        );
      }
    }

    final result =
        hourlyPoints.values.toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return result;
  }

  // Get recent stock changes (within the last N days)
  List<StockHistory> getRecentChanges({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return stockHistory.where((h) => h.timestamp.isAfter(cutoff)).toList();
  }

  // Check if stock status is volatile (changes frequently)
  bool get isVolatileStock {
    if (statusPoints.length < 5) return false;

    int changes = 0;
    for (int i = 1; i < statusPoints.length; i++) {
      if (statusPoints[i].isInStock != statusPoints[i - 1].isInStock) {
        changes++;
      }
    }

    // Consider volatile if more than 30% of checks resulted in status changes
    return (changes / statusPoints.length) > 0.3;
  }

  // Get the current trend (stable in stock, stable out of stock, or changing)
  String get currentTrend {
    if (statusPoints.isEmpty) return 'Unknown';
    if (statusPoints.length < 3) return 'Insufficient data';

    final recent =
        statusPoints.length > 5
            ? statusPoints.sublist(statusPoints.length - 5)
            : statusPoints;
    final allInStock = recent.every((p) => p.isInStock);
    final allOutOfStock = recent.every((p) => !p.isInStock);

    if (allInStock) return 'Consistently in stock';
    if (allOutOfStock) return 'Consistently out of stock';
    return 'Stock status changing';
  }
}
