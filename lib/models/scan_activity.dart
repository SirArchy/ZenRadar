// Model for background scan activities
class ScanActivity {
  final String id;
  final DateTime timestamp;
  final int itemsScanned;
  final int duration; // Duration in seconds
  final bool hasStockUpdates;
  final String? details; // Optional additional details
  final String scanType; // 'background', 'manual', 'favorites', or 'server'
  final List<Map<String, dynamic>>? stockUpdates; // Detailed stock update items
  final String? crawlRequestId; // Reference to the original crawl request

  ScanActivity({
    required this.id,
    required this.timestamp,
    required this.itemsScanned,
    required this.duration,
    required this.hasStockUpdates,
    this.details,
    this.scanType = 'background',
    this.stockUpdates,
    this.crawlRequestId,
  });

  factory ScanActivity.fromJson(Map<String, dynamic> json) {
    return ScanActivity(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      itemsScanned: json['itemsScanned'],
      duration: json['duration'],
      hasStockUpdates: json['hasStockUpdates'] == 1,
      details: json['details'],
      scanType: json['scanType'] ?? 'background',
      stockUpdates:
          json['stockUpdates'] != null
              ? List<Map<String, dynamic>>.from(json['stockUpdates'])
              : null,
      crawlRequestId: json['crawlRequestId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'itemsScanned': itemsScanned,
      'duration': duration,
      'hasStockUpdates': hasStockUpdates ? 1 : 0,
      'details': details,
      'scanType': scanType,
      'stockUpdates': stockUpdates,
      'crawlRequestId': crawlRequestId,
    };
  }

  String get formattedDuration {
    if (duration < 60) {
      return '${duration}s';
    } else if (duration < 3600) {
      return '${(duration / 60).round()}m ${duration % 60}s';
    } else {
      final hours = duration ~/ 3600;
      final minutes = (duration % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }
  }

  String get scanTypeDisplayName {
    switch (scanType) {
      case 'background':
        return 'Background';
      case 'manual':
        return 'Manual';
      case 'favorites':
        return 'Favorites';
      case 'server':
        return 'Server';
      default:
        return 'Unknown';
    }
  }
}
