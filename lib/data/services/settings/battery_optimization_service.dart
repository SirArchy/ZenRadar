// ignore_for_file: avoid_print

import 'package:flutter/services.dart';

class BatteryOptimizationService {
  static final BatteryOptimizationService _instance =
      BatteryOptimizationService._internal();
  factory BatteryOptimizationService() => _instance;
  BatteryOptimizationService._internal();

  static BatteryOptimizationService get instance => _instance;

  static const MethodChannel _channel = MethodChannel(
    'zenradar/battery_optimization',
  );

  /// Check if the app is ignored from battery optimization
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final bool isIgnoring = await _channel.invokeMethod(
        'isIgnoringBatteryOptimizations',
      );
      return isIgnoring;
    } catch (e) {
      print('Error checking battery optimization status: $e');
      return false;
    }
  }

  /// Request to ignore battery optimizations
  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final bool success = await _channel.invokeMethod(
        'requestIgnoreBatteryOptimizations',
      );
      return success;
    } catch (e) {
      print('Error requesting battery optimization exemption: $e');
      return false;
    }
  }

  /// Open battery optimization settings
  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      print('Error opening battery optimization settings: $e');
    }
  }

  /// Open autostart settings (manufacturer specific)
  Future<void> openAutoStartSettings() async {
    try {
      await _channel.invokeMethod('openAutoStartSettings');
    } catch (e) {
      print('Error opening autostart settings: $e');
    }
  }

  /// Check if exact alarm permission is granted (Android 12+)
  Future<bool> canScheduleExactAlarms() async {
    try {
      final bool canSchedule = await _channel.invokeMethod(
        'canScheduleExactAlarms',
      );
      return canSchedule;
    } catch (e) {
      print('Error checking exact alarm permission: $e');
      return false;
    }
  }

  /// Request exact alarm permission (Android 12+)
  Future<void> requestExactAlarmPermission() async {
    try {
      await _channel.invokeMethod('requestExactAlarmPermission');
    } catch (e) {
      print('Error requesting exact alarm permission: $e');
    }
  }

  /// Get device manufacturer for specific optimization handling
  Future<String> getDeviceManufacturer() async {
    try {
      final String manufacturer = await _channel.invokeMethod(
        'getManufacturer',
      );
      return manufacturer.toLowerCase();
    } catch (e) {
      print('Error getting device manufacturer: $e');
      return 'unknown';
    }
  }

  /// Check for manufacturer-specific battery optimization issues
  Future<Map<String, dynamic>> checkManufacturerOptimizations() async {
    final manufacturer = await getDeviceManufacturer();
    final Map<String, dynamic> result = {
      'manufacturer': manufacturer,
      'needsSpecialHandling': false,
      'recommendations': <String>[],
    };

    switch (manufacturer) {
      case 'xiaomi':
      case 'redmi':
        result['needsSpecialHandling'] = true;
        result['recommendations'] = [
          'Enable Autostart in Security app',
          'Disable battery optimization for ZenRadar',
          'Set battery saver to "No restrictions"',
          'Pin app to recent apps to prevent killing',
        ];
        break;
      case 'huawei':
      case 'honor':
        result['needsSpecialHandling'] = true;
        result['recommendations'] = [
          'Enable "Launch" for ZenRadar in Phone Manager',
          'Add ZenRadar to protected apps',
          'Disable "Close apps after screen lock"',
          'Set power mode to Performance or Smart',
        ];
        break;
      case 'oppo':
      case 'oneplus':
        result['needsSpecialHandling'] = true;
        result['recommendations'] = [
          'Enable "Auto-launch" in ColorOS Settings',
          'Set battery optimization to "Don\'t optimize"',
          'Add to startup manager whitelist',
          'Disable battery optimization in Phone Manager',
        ];
        break;
      case 'vivo':
        result['needsSpecialHandling'] = true;
        result['recommendations'] = [
          'Enable "Background app refresh"',
          'Add to high background app consumption whitelist',
          'Enable "Auto-start management"',
          'Set to "No restrictions" in battery settings',
        ];
        break;
      case 'samsung':
        result['needsSpecialHandling'] = true;
        result['recommendations'] = [
          'Add ZenRadar to "Never sleeping apps"',
          'Disable "Put unused apps to sleep"',
          'Set "Optimize battery usage" to "Don\'t optimize"',
          'Disable "Adaptive battery" if needed',
        ];
        break;
      case 'motorola':
        result['needsSpecialHandling'] = true;
        result['recommendations'] = [
          'Disable "Battery optimization" for ZenRadar',
          'Enable "Background activity" in app settings',
          'Turn off "Adaptive battery" if experiencing issues',
        ];
        break;
      default:
        result['recommendations'] = [
          'Disable battery optimization for ZenRadar',
          'Allow background app refresh',
          'Grant all necessary permissions',
        ];
    }

    return result;
  }

  /// Comprehensive battery optimization check and setup
  Future<Map<String, dynamic>> performBatteryOptimizationCheck() async {
    final Map<String, dynamic> result = {
      'batteryOptimizationIgnored': false,
      'exactAlarmPermission': false,
      'manufacturerSpecific': <String, dynamic>{},
      'allClear': false,
      'recommendations': <String>[],
    };

    try {
      // Check battery optimization status
      result['batteryOptimizationIgnored'] =
          await isIgnoringBatteryOptimizations();

      // Check exact alarm permission (Android 12+)
      result['exactAlarmPermission'] = await canScheduleExactAlarms();

      // Check manufacturer-specific optimizations
      result['manufacturerSpecific'] = await checkManufacturerOptimizations();

      // Determine if all requirements are met
      result['allClear'] =
          result['batteryOptimizationIgnored'] &&
          result['exactAlarmPermission'];

      // Add general recommendations if needed
      if (!result['batteryOptimizationIgnored']) {
        result['recommendations'].add(
          'Disable battery optimization for ZenRadar',
        );
      }

      if (!result['exactAlarmPermission']) {
        result['recommendations'].add(
          'Grant exact alarm permission for precise scheduling',
        );
      }

      // Add manufacturer-specific recommendations
      final manufacturerRecs =
          result['manufacturerSpecific']['recommendations'] as List;
      result['recommendations'].addAll(manufacturerRecs);

      print('Battery optimization check completed:');
      print(
        '  Battery optimization ignored: ${result['batteryOptimizationIgnored']}',
      );
      print('  Exact alarm permission: ${result['exactAlarmPermission']}');
      print(
        '  Manufacturer: ${result['manufacturerSpecific']['manufacturer']}',
      );
      print('  All clear: ${result['allClear']}');
    } catch (e) {
      print('Error during battery optimization check: $e');
    }

    return result;
  }

  /// Request all necessary permissions for background operation
  Future<bool> requestAllBatteryPermissions() async {
    try {
      print('Requesting battery optimization permissions...');

      // Request ignore battery optimization
      final batteryOptResult = await requestIgnoreBatteryOptimizations();
      print('Battery optimization request result: $batteryOptResult');

      // Request exact alarm permission
      await requestExactAlarmPermission();
      print('Exact alarm permission requested');

      // Wait a moment for permissions to be processed
      await Future.delayed(const Duration(seconds: 2));

      // Check final status
      final finalCheck = await performBatteryOptimizationCheck();
      return finalCheck['allClear'];
    } catch (e) {
      print('Error requesting battery permissions: $e');
      return false;
    }
  }

  /// Comprehensive check and handling of battery optimization
  Future<void> checkAndHandleBatteryOptimization() async {
    try {
      // Check if battery optimization is already disabled
      final isIgnoring = await isIgnoringBatteryOptimizations();

      if (isIgnoring) {
        print('Battery optimization already disabled');
        return;
      }

      // Check exact alarm permission (Android 12+)
      final canScheduleAlarms = await canScheduleExactAlarms();

      if (!canScheduleAlarms) {
        print('Exact alarm permission needed');
        // Note: We don't automatically request this as it's handled in background service
      }

      // Log manufacturer for debugging
      final manufacturer = await getDeviceManufacturer();
      print('Device manufacturer: $manufacturer');
    } catch (e) {
      print('Error checking battery optimization: $e');
    }
  }
}
