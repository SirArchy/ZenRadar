// ignore_for_file: avoid_print, empty_catches

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zenradar/data/services/analytics/website_analytics_service.dart';
import 'package:zenradar/data/services/subscription/subscription_service.dart';
import 'package:zenradar/data/services/cache/cache_service.dart';
import 'package:zenradar/data/services/data/firestore_service.dart';
import 'package:zenradar/data/services/auth/auth_service.dart';
import 'package:zenradar/data/services/cache/image_cache_service.dart';
import 'package:zenradar/data/services/media/image_url_processor.dart';
import 'package:zenradar/models/scan_activity.dart';

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
      return false;
    }

    return true;
  }

  /// Start preloading data in the background after user authentication
  Future<void> startBackgroundPreload() async {
    // Don't start multiple preload operations
    if (_isPreloadingActive) {
      return;
    }

    // Verify user authentication before starting any preloading
    if (!_shouldProceedWithFirestore()) {
      return;
    }

    _isPreloadingActive = true;
    _initialPreloadCompleter = Completer<void>();

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
        _hasCompletedInitialPreload = true;
        _initialPreloadCompleter?.complete();
        return;
      }

      // Get subscription status first to determine what to preload
      final isPremium = await SubscriptionService.instance.isPremiumUser();

      // For free users, we only need to load data for 5 websites

      // Start all preloading tasks in parallel
      final futures = <Future<void>>[
        _preloadWebsiteAnalytics(isPremium),
        _preloadRecentActivity(isPremium),
        _preloadFastSummaries(),
        _preloadProductImages(isPremium),
      ];

      // Wait for all to complete, but don't let one failure block others
      await Future.wait(futures.map((future) => future.catchError((e) {})));

      _hasCompletedInitialPreload = true;
      _initialPreloadCompleter?.complete();
    } catch (e) {
      _initialPreloadCompleter?.completeError(e);
    } finally {
      _isPreloadingActive = false;
    }
  }

  /// Preload website analytics for different time ranges
  Future<void> _preloadWebsiteAnalytics(bool isPremium) async {
    try {
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
        } catch (e) {}
      });

      await Future.wait(futures);
    } catch (e) {
      // Don't rethrow - let other preload tasks continue
    }
  }

  /// Preload recent activity data
  Future<void> _preloadRecentActivity(bool isPremium) async {
    try {
      const cacheKey = 'recent_activities_preload';

      // Check if we already have cached activities
      final cachedActivities = await CacheService.getCache<List<dynamic>>(
        cacheKey,
      );
      if (cachedActivities != null && cachedActivities.isNotEmpty) {
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
    } catch (e) {
      // Don't rethrow - let other preload tasks continue
    }
  }

  /// Preload fast summaries for quick screen loading
  Future<void> _preloadFastSummaries() async {
    try {
      final analyticsService = WebsiteAnalyticsService.instance;

      // Preload fast summaries for common time ranges
      final futures = ['day', 'week', 'month'].map((timeRange) async {
        try {
          await analyticsService.getFastSummary(
            timeRange: timeRange,
            forceRefresh: false,
          );
        } catch (e) {}
      });

      await Future.wait(futures);
    } catch (e) {
      // Don't rethrow - let other preload tasks continue
    }
  }

  /// Preload product images for faster loading
  Future<void> _preloadProductImages(bool isPremium) async {
    try {
      // Skip image preloading on web to avoid CORS issues
      if (kIsWeb) {
        return;
      }

      final imageCache = ImageCacheService.instance;
      final firestoreService = FirestoreService.instance;

      // Get recent products with images
      final limit = isPremium ? 100 : 50; // Limit based on subscription tier
      final paginatedProducts = await firestoreService.getProductsPaginated(
        page: 1,
        itemsPerPage: limit,
        sortBy: 'lastChecked',
        sortAscending: false,
      );
      final products = paginatedProducts.products;

      // Extract image URLs
      final rawImageUrls =
          products
              .where(
                (product) =>
                    product.imageUrl != null && product.imageUrl!.isNotEmpty,
              )
              .map((product) => product.imageUrl!)
              .toList();

      if (rawImageUrls.isNotEmpty) {
        // Process URLs to match what PlatformImage will use
        final processedImageUrls = ImageUrlProcessor.processImageUrls(
          rawImageUrls,
        );

        // Preload images with concurrency control
        await imageCache.preloadProductImages(
          processedImageUrls,
          maxConcurrent:
              isPremium ? 5 : 3, // Premium users get higher concurrency
          cacheDuration: const Duration(days: 7),
        );
      } else {}
    } catch (e) {
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

    // Extract scan details from the actual document structure
    // Use the same field names as recent_scans.dart
    final totalProducts = (crawlRequest['totalProducts'] ?? 0) as int;
    final stockUpdates = (crawlRequest['stockUpdates'] ?? 0) as int;
    final sitesProcessed = (crawlRequest['sitesProcessed'] ?? 0) as int;
    final status = crawlRequest['status'] ?? 'unknown';
    final requestId = crawlRequest['id'] ?? 'unknown';

    // Calculate duration from duration field (in milliseconds)
    int durationInSeconds = 0;
    final durationMs = crawlRequest['duration'];
    if (durationMs != null && durationMs is int && durationMs > 0) {
      durationInSeconds = (durationMs / 1000).round();
    }

    final hasStockUpdates = stockUpdates > 0;

    // Build detailed status message based on actual data
    String details;
    switch (status) {
      case 'completed':
        details =
            'Scanned $totalProducts products across $sitesProcessed sites';
        if (hasStockUpdates) {
          details += ' - $stockUpdates stock updates found';
        }
        break;
      case 'running':
        details = 'Scan in progress - $totalProducts products found so far';
        break;
      case 'failed':
        details = 'Scan failed';
        break;
      case 'pending':
        details = 'Scan queued for processing';
        break;
      default:
        details =
            hasStockUpdates
                ? '$stockUpdates stock updates found'
                : (totalProducts > 0 ? 'no updates' : 'No data available');
        break;
    }

    return ScanActivity(
      id: 'server_${requestId}_${timestamp.millisecondsSinceEpoch}',
      timestamp: timestamp,
      itemsScanned: totalProducts, // This was the bug - using correct field
      duration: durationInSeconds,
      hasStockUpdates: hasStockUpdates,
      details: details,
      scanType: 'server',
      crawlRequestId: requestId,
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
      return null;
    }
  }

  /// Force refresh all preloaded data
  Future<void> refreshPreloadedData() async {
    // Clear relevant caches
    await CacheService.clearCache('recent_activities_preload');

    // Clear image cache if needed
    try {
      final imageCacheSize =
          await ImageCacheService.instance.getCacheSizeInfo();
      final totalSizeMB = double.parse(imageCacheSize['totalSizeMB'] as String);

      // Clear image cache if it's getting too large (>100MB)
      if (totalSizeMB > 100) {
        await ImageCacheService.instance.cleanupExpiredCache();
      }
    } catch (e) {}

    // Restart preloading
    _hasCompletedInitialPreload = false;
    await startBackgroundPreload();
  }

  /// Reset preload service state (useful for debugging/troubleshooting)
  void resetPreloadService() {
    _isPreloadingActive = false;
    _hasCompletedInitialPreload = false;
    _initialPreloadCompleter?.complete();
    _initialPreloadCompleter = null;
  }
}

/// Extension to make unawaited calls more explicit
extension Unawaited on Future<void> {
  void get unawaited => then((_) {}, onError: (_) {});
}
