// Test script to verify manual crawl functionality
// This tests the complete workflow from Flutter → Firebase Function → Cloud Run

// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('🧪 Testing Manual Crawl Integration');
  print('=' * 50);

  await testManualCrawlEndToEnd();
}

Future<void> testManualCrawlEndToEnd() async {
  try {
    print('📡 Sending manual crawl request...');

    final response = await http
        .post(
          Uri.parse(
            'https://europe-west3-zenradar-acb85.cloudfunctions.net/triggerManualCrawl',
          ),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'sites': ['tokichi', 'marukyu'], // Test with 2 sites
            'userId': 'flutter-test-${DateTime.now().millisecondsSinceEpoch}',
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final requestId = data['requestId'];

      print('✅ Manual crawl triggered successfully!');
      print('🆔 Request ID: $requestId');
      print('📄 Full Response: ${response.body}');

      // Wait a bit and then check if we can see the request processing
      print('\n⏳ Waiting 10 seconds to check request status...');
      await Future.delayed(const Duration(seconds: 10));

      // Try to check status (this would normally be done via Firestore in the real app)
      print('ℹ️ In the real app, you would check Firestore for request status');
      print(
        '📱 The Flutter UI should show the request ID and allow status tracking',
      );
    } else {
      print('❌ Manual crawl failed');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
    }
  } catch (e) {
    print('❌ Error testing manual crawl: $e');
  }
}
