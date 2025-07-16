import 'dart:async';
import 'package:flutter/foundation.dart';

class CrawlerActivity {
  final String message;
  final DateTime timestamp;
  final CrawlerActivityType type;
  final String? siteName;

  CrawlerActivity({
    required this.message,
    required this.timestamp,
    required this.type,
    this.siteName,
  });
}

enum CrawlerActivityType { info, success, warning, error, progress }

class CrawlerLogger {
  static final CrawlerLogger _instance = CrawlerLogger._internal();
  factory CrawlerLogger() => _instance;
  CrawlerLogger._internal();

  static CrawlerLogger get instance => _instance;

  final StreamController<CrawlerActivity> _activityController =
      StreamController<CrawlerActivity>.broadcast();

  final List<CrawlerActivity> _activities = [];
  static const int _maxActivities = 100;

  bool _headModeEnabled = false;

  Stream<CrawlerActivity> get activityStream => _activityController.stream;
  List<CrawlerActivity> get activities => List.unmodifiable(_activities);

  bool get isHeadModeEnabled => _headModeEnabled;

  void setHeadMode(bool enabled) {
    _headModeEnabled = enabled;
    if (enabled) {
      logInfo('Head mode enabled - showing crawler activity');
    } else {
      logInfo('Head mode disabled - hiding crawler activity');
    }
  }

  void _addActivity(CrawlerActivity activity) {
    _activities.insert(0, activity);

    // Keep only the most recent activities
    if (_activities.length > _maxActivities) {
      _activities.removeRange(_maxActivities, _activities.length);
    }

    _activityController.add(activity);

    // Also log to console in debug mode
    if (kDebugMode) {
      debugPrint('[${activity.type.name.toUpperCase()}] ${activity.message}');
    }
  }

  void logInfo(String message, {String? siteName}) {
    if (!_headModeEnabled) return;

    _addActivity(
      CrawlerActivity(
        message: message,
        timestamp: DateTime.now(),
        type: CrawlerActivityType.info,
        siteName: siteName,
      ),
    );
  }

  void logSuccess(String message, {String? siteName}) {
    if (!_headModeEnabled) return;

    _addActivity(
      CrawlerActivity(
        message: message,
        timestamp: DateTime.now(),
        type: CrawlerActivityType.success,
        siteName: siteName,
      ),
    );
  }

  void logWarning(String message, {String? siteName}) {
    if (!_headModeEnabled) return;

    _addActivity(
      CrawlerActivity(
        message: message,
        timestamp: DateTime.now(),
        type: CrawlerActivityType.warning,
        siteName: siteName,
      ),
    );
  }

  void logError(String message, {String? siteName}) {
    if (!_headModeEnabled) return;

    _addActivity(
      CrawlerActivity(
        message: message,
        timestamp: DateTime.now(),
        type: CrawlerActivityType.error,
        siteName: siteName,
      ),
    );
  }

  void logProgress(String message, {String? siteName}) {
    if (!_headModeEnabled) return;

    _addActivity(
      CrawlerActivity(
        message: message,
        timestamp: DateTime.now(),
        type: CrawlerActivityType.progress,
        siteName: siteName,
      ),
    );
  }

  void clearActivities() {
    _activities.clear();
  }

  void dispose() {
    _activityController.close();
  }
}
