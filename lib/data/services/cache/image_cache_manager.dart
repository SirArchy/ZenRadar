// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:zenradar/data/services/cache/image_cache_service.dart';
import 'package:zenradar/data/services/cache/preload_service.dart';

/// Helper class for managing image cache in the home screen
class ImageCacheManager {
  static final ImageCacheManager _instance = ImageCacheManager._internal();
  static ImageCacheManager get instance => _instance;
  ImageCacheManager._internal();

  /// Initialize image cache management
  Future<void> initialize() async {
    if (kDebugMode) {}

    // Clean up expired cache entries on startup
    await ImageCacheService.instance.cleanupExpiredCache();

    // Log cache statistics

    if (kDebugMode) {}
  }

  /// Preload images for visible products
  Future<void> preloadVisibleProducts(List<String> imageUrls) async {
    if (imageUrls.isEmpty) return;

    // On web, browser handles image caching automatically
    if (kIsWeb) {
      if (kDebugMode) {}
      return;
    }

    try {
      // Filter out already cached images to avoid unnecessary network calls
      final uncachedUrls = <String>[];
      for (final url in imageUrls) {
        if (!await ImageCacheService.instance.isCached(url)) {
          uncachedUrls.add(url);
        }
      }

      if (uncachedUrls.isNotEmpty) {
        if (kDebugMode) {}

        await ImageCacheService.instance.preloadProductImages(
          uncachedUrls,
          maxConcurrent:
              3, // Conservative concurrency to avoid overwhelming the network
          cacheDuration: const Duration(days: 7),
        );
      } else {
        if (kDebugMode) {}
      }
    } catch (e) {
      if (kDebugMode) {}
    }
  }

  /// Get cache information for debugging/settings
  Future<Map<String, dynamic>> getCacheInfo() async {
    final stats = ImageCacheService.instance.cacheStats;
    final sizeInfo = await ImageCacheService.instance.getCacheSizeInfo();

    return {
      'statistics': stats,
      'sizeInfo': sizeInfo,
      'hitRate': '${(stats['hitRate'] * 100).toStringAsFixed(1)}%',
      'totalSize': sizeInfo['totalSizeMB'],
      'recommendation': _getCacheRecommendation(stats, sizeInfo),
    };
  }

  /// Get cache management recommendation
  String _getCacheRecommendation(
    Map<String, dynamic> stats,
    Map<String, dynamic> sizeInfo,
  ) {
    final hitRate = stats['hitRate'] as double;
    final totalSizeMB = double.parse(sizeInfo['totalSizeMB'] as String);
    final memoryFiles = stats['memoryCacheSize'] as int;

    if (hitRate < 0.5) {
      return 'Low cache hit rate. Consider preloading more images.';
    } else if (totalSizeMB > 200) {
      return 'Large cache size. Consider clearing old entries.';
    } else if (memoryFiles < 10) {
      return 'Low memory cache usage. Performance could be improved.';
    } else {
      return 'Cache performance is optimal.';
    }
  }

  /// Clear cache if it becomes too large
  Future<void> manageCacheSize() async {
    try {
      final sizeInfo = await ImageCacheService.instance.getCacheSizeInfo();
      final totalSizeMB = double.parse(sizeInfo['totalSizeMB'] as String);

      if (totalSizeMB > 150) {
        // 150MB threshold
        if (kDebugMode) {}

        // First try cleaning up expired entries
        await ImageCacheService.instance.cleanupExpiredCache();

        // Check size again
        final newSizeInfo = await ImageCacheService.instance.getCacheSizeInfo();
        final newTotalSizeMB = double.parse(
          newSizeInfo['totalSizeMB'] as String,
        );

        // If still too large, clear all cache
        if (newTotalSizeMB > 100) {
          if (kDebugMode) {}
          await ImageCacheService.instance.clearAllImages();
        }
      }
    } catch (e) {
      if (kDebugMode) {}
    }
  }

  /// Force refresh image cache (for settings/debugging)
  Future<void> refreshCache() async {
    if (kDebugMode) {}

    await ImageCacheService.instance.clearAllImages();
    await PreloadService.instance.refreshPreloadedData();

    if (kDebugMode) {}
  }

  /// Get formatted cache statistics for UI display
  Map<String, String> getFormattedStats() {
    final stats = ImageCacheService.instance.cacheStats;

    return {
      'Cache Hits': stats['hits'].toString(),
      'Cache Misses': stats['misses'].toString(),
      'Hit Rate': '${(stats['hitRate'] * 100).toStringAsFixed(1)}%',
      'Memory Cache': '${stats['memoryCacheSize']} images',
      'Network Requests': stats['networkRequests'].toString(),
    };
  }
}
