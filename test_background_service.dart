// Test script to verify background service functionality
// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'lib/services/background_service.dart';
import 'lib/services/notification_service.dart';
import 'lib/services/database_service.dart';

void main() async {
  print('🧪 Testing ZenRadar Background Service...');

  try {
    // Initialize services
    await DatabaseService.platformService.initDatabase();
    print('✅ Database initialized');

    if (!kIsWeb) {
      await NotificationService.instance.init();
      print('✅ Notification service initialized');

      // Test notification
      await NotificationService.instance.showTestNotification();
      print('✅ Test notification sent');

      // Initialize background service
      await initializeService();
      print('✅ Background service initialized');

      // Check if service is running
      final isRunning =
          await BackgroundServiceController.instance.isServiceRunning();
      print('Background service running: $isRunning');

      // Trigger manual check
      print('🚀 Triggering manual stock check...');
      await BackgroundServiceController.instance.triggerManualCheck();
      print('✅ Manual check triggered');
    } else {
      print('⚠️ Running on web, background service features limited');
    }
  } catch (e) {
    print('❌ Error during test: $e');
  }
}
