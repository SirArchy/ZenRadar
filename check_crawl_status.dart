// Check Firestore crawl request status
// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final requestId = 'Pt4tzsIpSkePx5tZrX6n'; // Latest request ID

  print('🔍 Checking status of crawl request: $requestId');
  print('=' * 50);

  // Wait a bit for the processing to happen
  await Future.delayed(const Duration(seconds: 5));

  // Check Cloud Run service logs by making a health check
  await checkCloudRunHealth();

  print('\n📋 To check the Firestore document status:');
  print('1. Go to Firebase Console');
  print('2. Navigate to Firestore Database');
  print('3. Check crawl_requests/$requestId');
  print('4. Look for status, error, and results fields');
}

Future<void> checkCloudRunHealth() async {
  try {
    print('\n🏥 Checking Cloud Run service health...');

    final response = await http
        .get(
          Uri.parse(
            'https://zenradar-crawler-989787576521.europe-west3.run.app/health',
          ),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final health = json.decode(response.body);
      print('✅ Cloud Run Service Health: ${health['status']}');
      print('📅 Timestamp: ${health['timestamp']}');
      print('🏷️ Version: ${health['version']}');
    } else {
      print('❌ Health check failed: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error checking health: $e');
  }
}
