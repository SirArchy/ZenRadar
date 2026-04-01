/// Background service for server mode only.
/// Local mode has been removed due to reliability issues.
Future<void> initializeService() async {
  // Server mode uses cloud-based monitoring, no local background processing needed
}

/// Background service controller for server mode.
class BackgroundServiceController {
  static Future<void> initializeService() async {
    // Server mode uses cloud-based monitoring, no local background processing needed
  }

  static Future<void> startService() async {
    // No-op for server mode
  }

  static Future<void> stopService() async {
    // No-op for server mode
  }

  static Future<bool> isServiceRunning() async {
    // In server mode, always return false as there's no local service
    return false;
  }
}
