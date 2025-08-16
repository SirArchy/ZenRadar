// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Test script to verify the complete cloud integration
/// Tests: Firebase Function → Cloud Run → Response
void main() async {
  await testCloudIntegration();
}

Future<void> testCloudIntegration() async {
  print('🚀 Testing ZenRadar Cloud Integration');
  print('=' * 50);

  // Test 1: Health Check on Cloud Run directly
  await testCloudRunHealth();

  // Test 2: Firebase Function triggering manual crawl
  await testFirebaseFunction();

  // Test 3: Test without Firebase auth (simulated user)
  await testSimpleRequest();
}

Future<void> testCloudRunHealth() async {
  print('\n1️⃣ Testing Cloud Run Health Check');
  print('-' * 30);

  try {
    final response = await http
        .get(
          Uri.parse(
            'https://zenradar-crawler-989787576521.europe-west3.run.app/health',
          ),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      print('✅ Cloud Run Health: ${response.body}');
    } else {
      print('❌ Cloud Run Health Check Failed: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Cloud Run Error: $e');
  }
}

Future<void> testFirebaseFunction() async {
  print('\n2️⃣ Testing Firebase Function (Manual Crawl)');
  print('-' * 30);

  try {
    final response = await http
        .post(
          Uri.parse(
            'https://europe-west3-zenradar-acb85.cloudfunctions.net/triggerManualCrawl',
          ),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'sites': ['tokichi', 'marukyu'],
            'userId': 'test-user-123',
          }),
        )
        .timeout(const Duration(seconds: 30));

    print('📡 Function Response Status: ${response.statusCode}');
    print('📡 Function Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ Manual Crawl Triggered: ${data['requestId']}');
    } else {
      print('❌ Function Call Failed');
    }
  } catch (e) {
    print('❌ Firebase Function Error: $e');
  }
}

Future<void> testSimpleRequest() async {
  print('\n3️⃣ Testing Direct Cloud Run Crawl');
  print('-' * 30);

  try {
    final response = await http
        .post(
          Uri.parse(
            'https://zenradar-crawler-989787576521.europe-west3.run.app/crawl',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization':
                'Bearer test-token', // This might fail without proper auth
          },
          body: json.encode({
            'sites': ['tokichi'],
            'requestId': 'direct-test-${DateTime.now().millisecondsSinceEpoch}',
          }),
        )
        .timeout(const Duration(seconds: 30));

    print('📡 Direct Crawl Status: ${response.statusCode}');
    print('📡 Direct Crawl Response: ${response.body}');

    if (response.statusCode == 200) {
      print('✅ Direct crawl successful');
    } else {
      print('⚠️ Direct crawl failed (expected without proper auth)');
    }
  } catch (e) {
    print('⚠️ Direct Crawl Error (expected): $e');
  }
}
