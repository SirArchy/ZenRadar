// ignore_for_file: avoid_print

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/website_analytics_service.dart';
import '../services/subscription_service.dart';
import '../services/cache_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/scan_activity.dart';

class PreloadService {
  static final PreloadService _instance = PreloadService._internal();
  static PreloadService get instance => _instance;

  PreloadService._internal();

  bool _isPreloadingActive = false;
  bool _hasCompletedInitialPreload = false;

  // Completer for tracking when initial preload is done
  Completer<void>? _initialPreloadCompleter;

  /// Check if Firestore operations should proceed (user authenticated and ready)
  bool _shouldProceedWithFirestore() {
    final authService = AuthService.instance;
    final isAuthenticated =
        authService.isSignedIn && authService.currentUser != null;

    if (!isAuthenticated) {
      print('⚠️ Skipping Firestore operation - user not authenticated');
      return false;
    }

    return true;
  }

  /// Start preloading data in the background immediately when app starts
  Future<void> startBackgroundPreload() async {
    if (_isPreloadingActive) return;

    _isPreloadingActive = true;
    _initialPreloadCompleter = Completer<void>();

    print('🚀 Starting background data preload...');

    // Run all preloading in parallel without blocking
    unawaited(_preloadAllData());
  }

  /// Wait for initial preload to complete (useful for screens that want to wait)
  Future<void> waitForInitialPreload() async {
    if (_hasCompletedInitialPreload) return;
    if (_initialPreloadCompleter != null) {
      await _initialPreloadCompleter!.future;
    }
  }

  /// Check if initial preload has completed
  bool get hasCompletedInitialPreload => _hasCompletedInitialPreload;

  Future<void> _preloadAllData() async {
    try {
      // Check if user is authenticated and we should proceed with Firestore operations
      if (!_shouldProceedWithFirestore()) {
        print('⚠️ User not authenticated, skipping preload');
        _hasCompletedInitialPreload = true;
        _initialPreloadCompleter?.complete();
        return;
      }

      print('✅ User authenticated, proceeding with preload');

      // Get subscription status first to determine what to preload
      final isPremium = await SubscriptionService.instance.isPremiumUser();
      print(
        '📊 User is ${isPremium ? 'Premium' : 'Free'} - adjusting preload strategy',
      );

      // For free users, we only need to load data for 5 websites
      final List<String> sitesToPreload =
          isPremium
              ? WebsiteAnalyticsService.supportedWebsites
              : ['tokichi', 'marukyu', 'ippodo', 'yoshien', 'matcha-karu'];

      print(
        '🎯 Preloading data for ${sitesToPreload.length} websites: ${sitesToPreload.join(', ')}',
      );

      // Start all preloading tasks in parallel
      final futures = <Future<void>>[
        _preloadWebsiteAnalytics(isPremium),
        _preloadRecentActivity(isPremium),
        _preloadFastSummaries(),
      ];

      // Wait for all to complete, but don't let one failure block others
      await Future.wait(
        futures.map(
          (future) => future.catchError((e) {
            print('⚠️ Preload task failed: $e');
          }),
        ),
      );

      print('✅ Background preload completed successfully');

      _hasCompletedInitialPreload = true;
      _initialPreloadCompleter?.complete();
    } catch (e) {
      print('❌ Background preload failed: $e');
      _initialPreloadCompleter?.completeError(e);
    } finally {
      _isPreloadingActive = false;
    }
  }

  /// Preload website analytics for different time ranges
  Future<void> _preloadWebsiteAnalytics(bool isPremium) async {
    try {
      print('📈 Preloading website analytics...');

      final analyticsService = WebsiteAnalyticsService.instance;

      // For free users, only preload 'day' range; for premium users, preload common ranges
      final timeRangesToPreload =
          isPremium ? ['day', 'week', 'month'] : ['day'];

      // Preload analytics for each time range in parallel
      final futures = timeRangesToPreload.map((timeRange) async {
        try {
          await analyticsService.getAllWebsiteAnalytics(
            timeRange: timeRange,
            forceRefresh: false, // Use cache if available
          );
          print('✓ Preloaded analytics for $timeRange range');
        } catch (e) {
          print('⚠️ Failed to preload analytics for $timeRange: $e');
        }
      });

      await Future.wait(futures);
      print('📈 Website analytics preload completed');
    } catch (e) {
      print('❌ Website analytics preload failed: $e');
      // Don't rethrow - let other preload tasks continue
    }
  }

  /// Preload recent activity data
  Future<void> _preloadRecentActivity(bool isPremium) async {
    try {
      print('📋 Preloading recent activity...');

      const cacheKey = 'recent_activities_preload';

      // Check if we already have cached activities
      final cachedActivities = await CacheService.getCache<List<dynamic>>(
        cacheKey,
      );
      if (cachedActivities != null && cachedActivities.isNotEmpty) {
        print('✓ Recent activities already in cache');
        return;
      }

      // Load from Firestore
      final activities = await _loadServerActivitiesFromFirestore(isPremium);

      // Cache the results
      await CacheService.setCache(
        cacheKey,
        activities.map((a) => a.toJson()).toList(),
        duration: const Duration(minutes: 10),
      );

      print('✓ Preloaded ${activities.length} recent activities');
    } catch (e) {
      print('❌ Recent activity preload failed: $e');
      // Don't rethrow - let other preload tasks continue
    }
  }

  /// Preload fast summaries for quick screen loading
  Future<void> _preloadFastSummaries() async {
    try {
      print('⚡ Preloading fast summaries...');

      final analyticsService = WebsiteAnalyticsService.instance;

      // Preload fast summaries for common time ranges
      final futures = ['day', 'week', 'month'].map((timeRange) async {
        try {
          await analyticsService.getFastSummary(
            timeRange: timeRange,
            forceRefresh: false,
          );
          print('✓ Preloaded fast summary for $timeRange');
        } catch (e) {
          print('⚠️ Failed to preload fast summary for $timeRange: $e');
        }
      });

      await Future.wait(futures);
      print('⚡ Fast summaries preload completed');
    } catch (e) {
      print('❌ Fast summaries preload failed: $e');
      // Don't rethrow - let other preload tasks continue
    }
  }

  /// Load server activities from Firestore (similar to recent_scans.dart)
  Future<List<ScanActivity>> _loadServerActivitiesFromFirestore(
    bool isPremium,
  ) async {
    try {
      final firestoreService = FirestoreService.instance;

      // For free users, limit to last 24 activities; for premium, get more
      final limit = isPremium ? 100 : 50;

      // Use the same method as recent_scans.dart
      final crawlRequests = await firestoreService.getCrawlRequests(
        limit: limit,
      );

      final activities = <ScanActivity>[];

      for (final crawlRequest in crawlRequests) {
        try {
          final activity = _convertCrawlRequestToScanActivity(crawlRequest);
          activities.add(activity);
        } catch (e) {
          print('Error converting crawl request ${crawlRequest['id']}: $e');
          continue;
        }
      }

      // Sort by timestamp (most recent first)
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Apply final limit for free users
      final finalActivities =
          isPremium ? activities : activities.take(24).toList();

      return finalActivities;
    } catch (e) {
      print('Error loading server activities from Firestore: $e');
      return [];
    }
  }

  /// Convert crawl request to ScanActivity (similar to recent_scans.dart)
  ScanActivity _convertCrawlRequestToScanActivity(
    Map<String, dynamic> crawlRequest,
  ) {
    final timestamp =
        (crawlRequest['timestamp'] as Timestamp?)?.toDate() ??
        (crawlRequest['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.now();

    final crawlResult =
        crawlRequest['crawlResult'] as Map<String, dynamic>? ?? {};
    final totalProducts = crawlResult['totalProducts'] as int? ?? 0;
    final totalUpdates = crawlResult['totalUpdates'] as int? ?? 0;

    final details =
        totalUpdates > 0
            ? '$totalUpdates stock updates found'
            : 'No stock changes detected';

    return ScanActivity(
      id: crawlRequest['id'] as String? ?? '',
      timestamp: timestamp,
      itemsScanned: totalProducts,
      duration: (crawlRequest['executionTime'] as int?) ?? 0,
      hasStockUpdates: totalUpdates > 0,
      details: details,
      scanType: 'server',
      crawlRequestId: crawlRequest['id'] as String?,
    );
  }

  /// Get cached recent activities if available
  Future<List<ScanActivity>?> getCachedRecentActivities() async {
    try {
      const cacheKey = 'recent_activities_preload';
      final cachedData = await CacheService.getCache<List<dynamic>>(cacheKey);

      if (cachedData != null) {
        return cachedData
            .map((data) => ScanActivity.fromJson(data as Map<String, dynamic>))
            .toList();
      }

      return null;
    } catch (e) {
      print('Error getting cached activities: $e');
      return null;
    }
  }

  /// Force refresh all preloaded data
  Future<void> refreshPreloadedData() async {
    print('🔄 Refreshing preloaded data...');

    // Clear relevant caches
    await CacheService.clearCache('recent_activities_preload');

    // Restart preloading
    _hasCompletedInitialPreload = false;
    await startBackgroundPreload();
  }
}

/// Extension to make unawaited calls more explicit
extension Unawaited on Future<void> {
  void get unawaited =>
      then((_) {}, onError: (e) => print('Unawaited future error: $e'));
}
