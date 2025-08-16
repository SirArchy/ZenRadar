// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'lib/services/website_analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('Testing Website Analytics Service...');

  try {
    final service = WebsiteAnalyticsService.instance;

    // Test getting analytics for all websites
    print('🔍 Fetching analytics for all websites...');
    final analytics = await service.getAllWebsiteAnalytics(timeRange: 'month');

    print('📊 Found analytics for ${analytics.length} websites:');
    for (final siteAnalytics in analytics) {
      print(
        '  - ${siteAnalytics.siteName}: ${siteAnalytics.totalProducts} products, ${siteAnalytics.stockUpdates.length} updates',
      );
      if (siteAnalytics.lastStockChange != null) {
        print('    Last update: ${siteAnalytics.lastStockChange}');
      }
      if (siteAnalytics.mostActiveHour != null) {
        print(
          '    Most active hour: ${siteAnalytics.mostActiveHour!.toString().padLeft(2, '0')}:00',
        );
      }
      print(
        '    Update frequency: ${siteAnalytics.updateFrequencyDescription}',
      );
    }

    // Test overall summary
    print('\n📈 Overall Summary:');
    final summary = await service.getOverallSummary(timeRange: 'month');
    summary.forEach((key, value) {
      print('  $key: $value');
    });

    print('\n✅ Website Analytics Service test completed successfully!');
  } catch (e, stackTrace) {
    print('❌ Error testing Website Analytics Service: $e');
    print('Stack trace: $stackTrace');
  }
}
