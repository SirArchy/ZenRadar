// Model for background scan activities
class ScanActivity {
  final String id;
  final DateTime timestamp;
  final int itemsScanned;
  final int duration; // Duration in seconds
  final bool hasStockUpdates;
  final String? details; // Optional additional details
  final String scanType; // 'background', 'manual', or 'favorites'

  ScanActivity({
    required this.id,
    required this.timestamp,
    required this.itemsScanned,
    required this.duration,
    required this.hasStockUpdates,
    this.details,
    this.scanType = 'background',
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
      default:
        return 'Unknown';
    }
  }
}
