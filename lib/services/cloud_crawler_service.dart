// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Service for triggering and managing cloud-based crawls
/// Works with Firebase Cloud Functions and Cloud Run
class CloudCrawlerService {
  static final CloudCrawlerService _instance = CloudCrawlerService._internal();
  factory CloudCrawlerService() => _instance;
  CloudCrawlerService._internal();

  static CloudCrawlerService get instance => _instance;

  static const String _cloudFunctionUrl =
      'https://europe-west3-zenradar-acb85.cloudfunctions.net/triggerManualCrawl';

  /// Trigger a manual crawl for specific sites
  Future<String> triggerManualCrawl({
    List<String>? sites,
    required String userId,
  }) async {
    try {
      print('🔥 Triggering manual crawl for user: $userId');

      final response = await http
          .post(
            Uri.parse(_cloudFunctionUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'sites': sites ?? [], 'userId': userId}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final requestId = responseData['requestId'] as String;

        print('✅ Manual crawl triggered successfully: $requestId');
        return requestId;
      } else {
        throw Exception(
          'Failed to trigger crawl: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error triggering manual crawl: $e');
      rethrow;
    }
  }

  /// Check server health by making a simple HTTP request
  Future<ServerHealthStatus> checkServerHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              _cloudFunctionUrl.replaceAll('/triggerManualCrawl', '/health'),
            ),
          )
          .timeout(const Duration(seconds: 10));

      final isHealthy = response.statusCode == 200;

      return ServerHealthStatus(
        isHealthy: isHealthy,
        lastCrawlTime: isHealthy ? DateTime.now() : null,
        recentCrawlCount: isHealthy ? 1 : 0,
        message: isHealthy ? 'Server is responding' : 'Server not responding',
      );
    } catch (e) {
      print('❌ Error checking server health: $e');
      return ServerHealthStatus(
        isHealthy: false,
        lastCrawlTime: null,
        recentCrawlCount: 0,
        message: 'Failed to check server status: $e',
      );
    }
  }

  /// Simulate triggering crawl by making HTTP request
  /// (Simplified version without Firestore dependencies)
  Future<String> triggerCrawlSimple({
    List<String>? sites,
    String? userId,
  }) async {
    try {
      print('🚀 Triggering simple crawl request');

      // Generate a fake request ID for now
      final requestId = 'crawl_${DateTime.now().millisecondsSinceEpoch}';

      // In a real implementation, this would create a Firestore document
      // or make an HTTP request to your Cloud Function
      await Future.delayed(
        const Duration(seconds: 1),
      ); // Simulate network delay

      print('✅ Crawl request created: $requestId');
      return requestId;
    } catch (e) {
      print('❌ Error creating crawl request: $e');
      rethrow;
    }
  }
}

/// Model for crawl request status
class CrawlRequestStatus {
  final String requestId;
  final String status;
  final String? message;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? totalProducts;
  final int? stockUpdates;
  final List<String>? errors;

  CrawlRequestStatus({
    required this.requestId,
    required this.status,
    this.message,
    this.createdAt,
    this.startedAt,
    this.completedAt,
    this.totalProducts,
    this.stockUpdates,
    this.errors,
  });

  factory CrawlRequestStatus.fromMap(
    String requestId,
    Map<String, dynamic> data,
  ) {
    return CrawlRequestStatus(
      requestId: requestId,
      status: data['status'] ?? 'unknown',
      message: data['message'],
      createdAt:
          data['createdAt'] != null ? DateTime.parse(data['createdAt']) : null,
      startedAt:
          data['startedAt'] != null ? DateTime.parse(data['startedAt']) : null,
      completedAt:
          data['completedAt'] != null
              ? DateTime.parse(data['completedAt'])
              : null,
      totalProducts: data['results']?['totalProducts'],
      stockUpdates: data['results']?['stockUpdates'],
      errors:
          data['results']?['errors'] != null
              ? List<String>.from(data['results']['errors'])
              : null,
    );
  }

  String get displayStatus {
    switch (status) {
      case 'pending':
        return 'Waiting to start...';
      case 'processing':
        return 'Initializing...';
      case 'running':
        return 'Crawling websites...';
      case 'completed':
        return 'Completed successfully';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
      case 'processing':
        return Colors.orange;
      case 'running':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Model for server health status
class ServerHealthStatus {
  final bool isHealthy;
  final DateTime? lastCrawlTime;
  final int recentCrawlCount;
  final String message;

  ServerHealthStatus({
    required this.isHealthy,
    required this.lastCrawlTime,
    required this.recentCrawlCount,
    required this.message,
  });
}
