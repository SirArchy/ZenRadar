import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/scan_activity.dart';
import 'database_service.dart';

// Web-compatible background service (simulated background processing)
class WebBackgroundService {
  static final WebBackgroundService _instance =
      WebBackgroundService._internal();
  factory WebBackgroundService() => _instance;
  WebBackgroundService._internal();

  static WebBackgroundService get instance => _instance;

  Timer? _simulationTimer;
  final Random _random = Random();

  Future<void> init() async {
    if (kDebugMode) {
      print('Web background service initialized with simulation');
    }
  }

  Future<bool> isServiceRunning() async {
    return _simulationTimer?.isActive ?? false;
  }

  Future<void> startService() async {
    if (kDebugMode) {
      print('Starting simulated background service for web demo');
    }

    _simulationTimer?.cancel();

    // Create periodic timer to simulate background scans every 2-5 minutes
    _simulationTimer = Timer.periodic(
      Duration(minutes: 2 + _random.nextInt(3)),
      (timer) async {
        await _simulateBackgroundScan();
      },
    );

    // Create initial scan after 30 seconds
    Timer(const Duration(seconds: 30), () async {
      await _simulateBackgroundScan();
    });
  }

  Future<void> stopService() async {
    if (kDebugMode) {
      print('Stopping simulated background service');
    }
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  Future<void> _simulateBackgroundScan() async {
    try {
      if (kDebugMode) {
        print('🤖 Simulating background scan for web demo...');
      }

      final now = DateTime.now();
      final scanActivity = ScanActivity(
        id: 'sim_${now.millisecondsSinceEpoch}',
        timestamp: now,
        itemsScanned: 15 + _random.nextInt(35), // 15-50 items
        duration: 10 + _random.nextInt(40), // 10-50 seconds
        hasStockUpdates: _random.nextBool(),
        details: _generateSimulatedScanDetails(),
        scanType: 'background',
      );

      await DatabaseService.platformService.insertScanActivity(scanActivity);

      if (kDebugMode) {
        print(
          '✅ Simulated scan activity logged: ${scanActivity.itemsScanned} items in ${scanActivity.formattedDuration}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating simulated scan activity: $e');
      }
    }
  }

  String _generateSimulatedScanDetails() {
    final sites = [
      'Nakamura Tokichi',
      'Ippodo Tea',
      'Marukyu-Koyamaen',
      'Yoshi En',
      'Matcha Kāru',
    ];
    final selectedSites = <String>[];

    for (final site in sites) {
      if (_random.nextBool()) {
        selectedSites.add(site);
      }
    }

    if (selectedSites.isEmpty) {
      selectedSites.add(sites[_random.nextInt(sites.length)]);
    }

    return 'Monitored ${selectedSites.join(", ")}';
  }

  Future<void> triggerManualCheck() async {
    if (kDebugMode) {
      print('Manual check triggered (web mode) - creating simulated scan');
    }
    await _simulateBackgroundScan();
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
