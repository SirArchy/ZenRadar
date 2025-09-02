// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firebase_messaging_service.dart';
import 'subscription_service.dart';
import '../models/matcha_product.dart';

/// Result class for favorite update operations including subscription validation
class FavoriteUpdateResult {
  final bool success;
  final String? error;
  final bool limitReached;
  final FavoriteValidationResult? validationResult;

  const FavoriteUpdateResult({
    required this.success,
    required this.error,
    required this.limitReached,
    this.validationResult,
  });
}

/// Service to handle communication with Firebase backend for FCM and favorites
class BackendService {
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  static BackendService get instance => _instance;

  // Replace with your actual Firebase project region and ID
  static const String _functionsUrl =
      'https://europe-west3-zenradar-acb85.cloudfunctions.net';

  /// Update user's favorite status and sync with backend
  /// Now includes subscription tier validation for freemium model
  Future<FavoriteUpdateResult> updateFavorite({
    required String productId,
    required bool isFavorite,
  }) async {
    try {
      // Get current user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('❌ Backend: No authenticated user found');
        }
        return FavoriteUpdateResult(
          success: false,
          error: 'No authenticated user found',
          limitReached: false,
        );
      }

      // Check subscription limits when adding favorites
      if (isFavorite) {
        final favoriteValidation =
            await SubscriptionService.instance.canAddMoreFavorites();
        if (!favoriteValidation.canAdd) {
          if (kDebugMode) {
            print(
              '❌ Backend: Favorite limit reached for ${favoriteValidation.tier.displayName} tier',
            );
          }
          return FavoriteUpdateResult(
            success: false,
            error: favoriteValidation.message,
            limitReached: true,
            validationResult: favoriteValidation,
          );
        }
      }

      final requestData = {
        'userId': user.uid,
        'productId': productId,
        'isFavorite': isFavorite,
      };

      final response = await http.post(
        Uri.parse('$_functionsUrl/updateUserFavorites'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        // Update FCM subscription
        await FirebaseMessagingService.instance.onFavoriteChanged(
          productId,
          isFavorite,
        );

        if (kDebugMode) {
          print('✅ Backend: Favorite updated successfully');
        }
        return FavoriteUpdateResult(
          success: true,
          error: null,
          limitReached: false,
        );
      } else {
        if (kDebugMode) {
          print('❌ Backend: Failed to update favorite');
          print('❌ Backend: Status: ${response.statusCode}');
          print('❌ Backend: Response: ${response.body}');
        }
        return FavoriteUpdateResult(
          success: false,
          error: 'Server error: ${response.statusCode}',
          limitReached: false,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Backend: Error updating favorite: $e');
      }
      return FavoriteUpdateResult(
        success: false,
        error: 'Network error: $e',
        limitReached: false,
      );
    }
  }

  /// Trigger a manual crawl
  Future<bool> triggerManualCrawl({List<String> sites = const []}) async {
    try {
      // Get current user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('❌ Backend: No authenticated user found');
        }
        return false;
      }

      final requestData = {'userId': user.uid, 'sites': sites};

      final response = await http.post(
        Uri.parse('$_functionsUrl/triggerManualCrawl'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Backend: Manual crawl triggered successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('❌ Backend: Failed to trigger manual crawl');
          print('❌ Backend: Status: ${response.statusCode}');
          print('❌ Backend: Response: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Backend: Error triggering manual crawl: $e');
      }
      return false;
    }
  }

  /// Initialize FCM and register token with backend
  Future<void> initializeFCM() async {
    try {
      if (kDebugMode) {
        print('🚀 Backend: Initializing FCM service...');
      }

      await FirebaseMessagingService.instance.initialize();

      // Update subscriptions for existing favorites (happens in background)
      await FirebaseMessagingService.instance.updateFavoriteSubscriptions();

      if (kDebugMode) {
        print('✅ Backend: FCM initialized and subscriptions started');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Backend: Error initializing FCM: $e');
      }
    }
  }
}
