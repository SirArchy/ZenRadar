import 'package:flutter/foundation.dart';

// Web-compatible background service (no actual background processing)
class WebBackgroundService {
  static final WebBackgroundService _instance =
      WebBackgroundService._internal();
  factory WebBackgroundService() => _instance;
  WebBackgroundService._internal();

  static WebBackgroundService get instance => _instance;

  Future<void> init() async {
    if (kDebugMode) {
      print('Web background service initialized (no background processing)');
    }
  }

  Future<bool> isServiceRunning() async {
    return false; // No background service on web
  }

  Future<void> startService() async {
    if (kDebugMode) {
      print('Background service not available on web');
    }
  }

  Future<void> stopService() async {
    if (kDebugMode) {
      print('Background service not available on web');
    }
  }

  Future<void> triggerManualCheck() async {
    if (kDebugMode) {
      print('Manual check triggered (web mode)');
    }
    // On web, this would trigger the crawler service directly
  }

  Future<void> updateSettings() async {
    if (kDebugMode) {
      print('Settings updated (web mode)');
    }
  }
}

// Web-compatible background service controller
class WebBackgroundServiceController {
  static final WebBackgroundServiceController _instance =
      WebBackgroundServiceController._internal();
  factory WebBackgroundServiceController() => _instance;
  WebBackgroundServiceController._internal();

  static WebBackgroundServiceController get instance => _instance;

  Future<bool> isServiceRunning() async {
    return false;
  }

  Future<void> startService() async {
    // No-op on web
  }

  Future<void> stopService() async {
    // No-op on web
  }

  Future<void> triggerManualCheck() async {
    // On web, this could trigger the crawler directly
  }

  Future<void> updateSettings() async {
    // No-op on web
  }
}
