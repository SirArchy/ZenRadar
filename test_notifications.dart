// Test script specifically for notifications
// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'lib/services/notification_service.dart';

void main() async {
  print('🔔 Testing ZenRadar Notification System...');

  if (kIsWeb) {
    print('⚠️ Running on web, notification features may be limited');
    return;
  }

  try {
    // Initialize notification service
    await NotificationService.instance.init();
    print('✅ Notification service initialized');

    // Debug the notification system
    await NotificationService.instance.debugNotificationSystem();

    // Test basic notification
    await NotificationService.instance.showTestNotification();
    print('✅ Test notification sent');

    // Test stock alert notification
    await NotificationService.instance.showStockAlert(
      productName: 'Test Matcha Product',
      siteName: 'Test Site',
      productId: 'test_product_123',
    );
    print('✅ Stock alert notification sent');

    // Test summary notification
    await NotificationService.instance.showSummaryNotification(
      productNames: ['Matcha A', 'Matcha B', 'Matcha C'],
      siteName: 'Test Site',
    );
    print('✅ Summary notification sent');

    print(
      '🎉 All notification tests completed! Check your device for notifications.',
    );
  } catch (e) {
    print('❌ Error during notification test: $e');
  }
}
