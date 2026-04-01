import 'package:flutter/foundation.dart';

/// Background service for server mode only.
/// Local mode has been removed due to reliability issues.
Future<void> initializeService() async {
  if (kDebugMode) {
    print('Background service initialized for server mode');
  }
  // Server mode uses cloud-based monitoring, no local background processing needed
}

/// Background service controller for server mode.
class BackgroundServiceController {
  static Future<void> initializeService() async {
    if (kDebugMode) {
      print('BackgroundServiceController: Initialized for server mode');
    }
    // Server mode uses cloud-based monitoring, no local background processing needed
  }

  static Future<void> startService() async {
    if (kDebugMode) {
      print(
        'BackgroundServiceController: Service start requested (server mode - no local processing)',
      );
    }
    // No-op for server mode
  }

  static Future<void> stopService() async {
    if (kDebugMode) {
      print(
        'BackgroundServiceController: Service stop requested (server mode - no local processing)',
      );
    }
    // No-op for server mode
  }

  static Future<bool> isServiceRunning() async {
    // In server mode, always return false as there's no local service
    return false;
  }
}
