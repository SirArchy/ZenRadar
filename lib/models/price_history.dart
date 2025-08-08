import 'matcha_product.dart';

class PriceHistory {
  final String id;
  final String productId;
  final DateTime date;
  final double price;
  final String currency;
  final bool isInStock;

  PriceHistory({
    required this.id,
    required this.productId,
    required this.date,
    required this.price,
    required this.currency,
    required this.isInStock,
  });

  factory PriceHistory.fromJson(Map<String, dynamic> json) {
    return PriceHistory(
      id: json['id'],
      productId: json['productId'],
      date: DateTime.parse(json['date']),
      price: json['price']?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'EUR',
      isInStock: json['isInStock'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'date': date.toIso8601String(),
      'price': price,
      'currency': currency,
      'isInStock': isInStock ? 1 : 0,
    };
  }

  PriceHistory copyWith({
    String? id,
    String? productId,
    DateTime? date,
    double? price,
    String? currency,
    bool? isInStock,
  }) {
    return PriceHistory(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      date: date ?? this.date,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      isInStock: isInStock ?? this.isInStock,
    );
  }

  // Helper to create a unique daily key for grouping
  String get dailyKey {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Create a PriceHistory from a MatchaProduct
  factory PriceHistory.fromProduct(MatchaProduct product) {
    return PriceHistory(
      id: '${product.id}_${DateTime.now().millisecondsSinceEpoch}',
      productId: product.id,
      date: DateTime.now(),
      price: product.priceValue ?? 0.0,
      currency: product.currency ?? 'EUR',
      isInStock: product.isInStock,
    );
  }
}

class PriceAnalytics {
  final double currentPrice;
  final double? lowestPrice;
  final double? highestPrice;
  final double? averagePrice;
  final DateTime? lowestPriceDate;
  final DateTime? highestPriceDate;
  final int totalDataPoints;
  final double? priceChange; // Percentage change from first to last
  final List<PriceHistory> priceHistory;

  PriceAnalytics({
    required this.currentPrice,
    this.lowestPrice,
    this.highestPrice,
    this.averagePrice,
    this.lowestPriceDate,
    this.highestPriceDate,
    required this.totalDataPoints,
    this.priceChange,
    required this.priceHistory,
  });

  factory PriceAnalytics.fromHistory(List<PriceHistory> history) {
    if (history.isEmpty) {
      return PriceAnalytics(
        currentPrice: 0.0,
        totalDataPoints: 0,
        priceHistory: [],
      );
    }

    // Sort by date
    final sortedHistory = List<PriceHistory>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    final prices = sortedHistory.map((h) => h.price).toList();
    final currentPrice = sortedHistory.last.price;
    final lowestPrice = prices.reduce((a, b) => a < b ? a : b);
    final highestPrice = prices.reduce((a, b) => a > b ? a : b);
    final averagePrice = prices.reduce((a, b) => a + b) / prices.length;

    final lowestEntry = sortedHistory.firstWhere((h) => h.price == lowestPrice);
    final highestEntry = sortedHistory.firstWhere(
      (h) => h.price == highestPrice,
    );

    double? priceChange;
    if (sortedHistory.length > 1) {
      final firstPrice = sortedHistory.first.price;
      final lastPrice = sortedHistory.last.price;
      if (firstPrice > 0) {
        priceChange = ((lastPrice - firstPrice) / firstPrice) * 100;
      }
    }

    return PriceAnalytics(
      currentPrice: currentPrice,
      lowestPrice: lowestPrice,
      highestPrice: highestPrice,
      averagePrice: averagePrice,
      lowestPriceDate: lowestEntry.date,
      highestPriceDate: highestEntry.date,
      totalDataPoints: history.length,
      priceChange: priceChange,
      priceHistory: sortedHistory,
    );
  }

  // Get daily aggregated data (lowest price per day)
  List<PriceHistory> get dailyAggregatedHistory {
    final Map<String, PriceHistory> dailyMinimums = {};

    for (final entry in priceHistory) {
      final dailyKey = entry.dailyKey;

      if (!dailyMinimums.containsKey(dailyKey) ||
          entry.price < dailyMinimums[dailyKey]!.price) {
        dailyMinimums[dailyKey] = entry;
      }
    }

    final result =
        dailyMinimums.values.toList()..sort((a, b) => a.date.compareTo(b.date));

    return result;
  }

  // Get weekly aggregated data
  List<PriceHistory> get weeklyAggregatedHistory {
    final Map<String, PriceHistory> weeklyMinimums = {};

    for (final entry in priceHistory) {
      // Calculate week number
      final startOfYear = DateTime(entry.date.year, 1, 1);
      final daysSinceStart = entry.date.difference(startOfYear).inDays;
      final weekNumber = (daysSinceStart / 7).floor();
      final weekKey = '${entry.date.year}-W$weekNumber';

      if (!weeklyMinimums.containsKey(weekKey) ||
          entry.price < weeklyMinimums[weekKey]!.price) {
        weeklyMinimums[weekKey] = entry;
      }
    }

    final result =
        weeklyMinimums.values.toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return result;
  }

  // Get monthly aggregated data
  List<PriceHistory> get monthlyAggregatedHistory {
    final Map<String, PriceHistory> monthlyMinimums = {};

    for (final entry in priceHistory) {
      final monthKey =
          '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}';

      if (!monthlyMinimums.containsKey(monthKey) ||
          entry.price < monthlyMinimums[monthKey]!.price) {
        monthlyMinimums[monthKey] = entry;
      }
    }

    final result =
        monthlyMinimums.values.toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return result;
  }

  bool get hasPriceIncreased => priceChange != null && priceChange! > 0;
  bool get hasPriceDecreased => priceChange != null && priceChange! < 0;
  bool get isPriceStable =>
      priceChange != null && priceChange!.abs() < 1.0; // Less than 1% change
}
