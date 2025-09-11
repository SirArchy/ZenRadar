// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'cache_service.dart';

/// Enhanced image cache service for product images
/// Stores images both in memory and on disk to minimize Firebase Storage calls
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  static ImageCacheService get instance => _instance;
  ImageCacheService._internal();

  // In-memory cache for frequently accessed images
  static final Map<String, Uint8List> _memoryCache = {};
  static const int _maxMemoryCacheSize = 50; // Maximum images in memory
  static const int _maxImageSizeBytes = 2 * 1024 * 1024; // 2MB max per image
  static const Duration _defaultCacheDuration = Duration(
    days: 7,
  ); // 7 days cache
  static const Duration _metadataCacheDuration = Duration(
    days: 30,
  ); // Metadata cache longer

  // Cache statistics
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _networkRequests = 0;

  /// Cache hit rate (for performance monitoring)
  double get cacheHitRate {
    final total = _cacheHits + _cacheMisses;
    return total > 0 ? _cacheHits / total : 0.0;
  }

  /// Get cache statistics
  Map<String, dynamic> get cacheStats => {
    'hits': _cacheHits,
    'misses': _cacheMisses,
    'networkRequests': _networkRequests,
    'hitRate': cacheHitRate,
    'memoryCacheSize': _memoryCache.length,
  };

  /// Generate cache key from image URL
  String _generateCacheKey(String imageUrl) {
    // Clean URL and create consistent hash
    final cleanUrl = imageUrl.trim();
    final bytes = utf8.encode(cleanUrl);
    final digest = sha256.convert(bytes);
    return 'img_${digest.toString().substring(0, 16)}';
  }

  /// Get cache directory for images
  Future<Directory> _getCacheDirectory() async {
    Directory cacheDir;

    if (kIsWeb) {
      // Web doesn't support file storage, use in-memory only
      throw UnsupportedError('File storage not supported on web');
    }

    try {
      // Try to get application cache directory
      cacheDir = await getTemporaryDirectory();
      final imageCacheDir = Directory('${cacheDir.path}/image_cache');

      if (!await imageCacheDir.exists()) {
        await imageCacheDir.create(recursive: true);
      }

      return imageCacheDir;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ ImageCache: Could not access cache directory: $e');
      }
      rethrow;
    }
  }

  /// Check if image is cached (either in memory or disk)
  Future<bool> isCached(String imageUrl) async {
    final cacheKey = _generateCacheKey(imageUrl);

    // Check memory cache first
    if (_memoryCache.containsKey(cacheKey)) {
      return true;
    }

    // Check if metadata indicates valid disk cache
    if (kIsWeb) {
      return false; // Web only uses memory cache
    }

    try {
      final metadata = await _getCacheMetadata(cacheKey);
      if (metadata != null) {
        final expiration = DateTime.parse(metadata['expiration'] as String);
        return DateTime.now().isBefore(expiration);
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔍 ImageCache: Error checking cache metadata for $cacheKey: $e');
      }
    }

    return false;
  }

  /// Get cached image data
  Future<Uint8List?> getCachedImage(String imageUrl) async {
    final cacheKey = _generateCacheKey(imageUrl);

    // Check memory cache first
    if (_memoryCache.containsKey(cacheKey)) {
      _cacheHits++;
      if (kDebugMode) {
        print('📸 ImageCache: Memory hit for $cacheKey');
      }
      return _memoryCache[cacheKey];
    }

    // Check disk cache on non-web platforms
    if (!kIsWeb) {
      try {
        final metadata = await _getCacheMetadata(cacheKey);
        if (metadata != null) {
          final expiration = DateTime.parse(metadata['expiration'] as String);

          if (DateTime.now().isBefore(expiration)) {
            final cacheDir = await _getCacheDirectory();
            final file = File('${cacheDir.path}/$cacheKey.jpg');

            if (await file.exists()) {
              final imageData = await file.readAsBytes();

              // Store in memory cache if there's room
              _addToMemoryCache(cacheKey, imageData);

              _cacheHits++;
              if (kDebugMode) {
                print(
                  '💾 ImageCache: Disk hit for $cacheKey (${imageData.length} bytes)',
                );
              }
              return imageData;
            }
          } else {
            // Cache expired, clean up
            await _removeCachedImage(cacheKey);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ ImageCache: Error reading disk cache for $cacheKey: $e');
        }
      }
    }

    _cacheMisses++;
    if (kDebugMode) {
      print('❌ ImageCache: Miss for $cacheKey');
    }
    return null;
  }

  /// Download and cache image
  Future<Uint8List?> downloadAndCacheImage(
    String imageUrl, {
    Duration? cacheDuration,
    Map<String, String>? headers,
  }) async {
    final cacheKey = _generateCacheKey(imageUrl);

    try {
      _networkRequests++;
      if (kDebugMode) {
        print('🌐 ImageCache: Downloading $imageUrl');
      }

      final response = await http
          .get(
            Uri.parse(imageUrl),
            headers:
                headers ??
                {
                  'User-Agent': 'Mozilla/5.0 (compatible; ZenRadar/1.0)',
                  'Accept':
                      'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
                  'Cache-Control': 'no-cache',
                },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final imageData = response.bodyBytes;

        // Check image size
        if (imageData.length > _maxImageSizeBytes) {
          if (kDebugMode) {
            print(
              '⚠️ ImageCache: Image too large (${imageData.length} bytes), skipping cache',
            );
          }
          return imageData; // Return but don't cache
        }

        // Cache the image
        await _cacheImageData(
          cacheKey,
          imageData,
          imageUrl,
          cacheDuration ?? _defaultCacheDuration,
        );

        if (kDebugMode) {
          print(
            '✅ ImageCache: Downloaded and cached $cacheKey (${imageData.length} bytes)',
          );
        }

        return imageData;
      } else {
        if (kDebugMode) {
          print('❌ ImageCache: HTTP ${response.statusCode} for $imageUrl');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ImageCache: Download error for $imageUrl: $e');
      }
      return null;
    }
  }

  /// Cache image data both in memory and disk
  Future<void> _cacheImageData(
    String cacheKey,
    Uint8List imageData,
    String originalUrl,
    Duration cacheDuration,
  ) async {
    // Store in memory cache
    _addToMemoryCache(cacheKey, imageData);

    // Store on disk (non-web only)
    if (!kIsWeb) {
      try {
        final cacheDir = await _getCacheDirectory();
        final file = File('${cacheDir.path}/$cacheKey.jpg');
        await file.writeAsBytes(imageData);

        // Store metadata
        await _storeCacheMetadata(cacheKey, originalUrl, cacheDuration);

        if (kDebugMode) {
          print('💾 ImageCache: Stored to disk $cacheKey');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ ImageCache: Error storing to disk for $cacheKey: $e');
        }
      }
    }
  }

  /// Add image to memory cache with size management
  void _addToMemoryCache(String cacheKey, Uint8List imageData) {
    // Remove oldest items if cache is full
    while (_memoryCache.length >= _maxMemoryCacheSize) {
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
      if (kDebugMode) {
        print('🧹 ImageCache: Removed $oldestKey from memory cache');
      }
    }

    _memoryCache[cacheKey] = imageData;
  }

  /// Store cache metadata
  Future<void> _storeCacheMetadata(
    String cacheKey,
    String originalUrl,
    Duration cacheDuration,
  ) async {
    final now = DateTime.now();
    final expiration = now.add(cacheDuration);

    final metadata = {
      'cacheKey': cacheKey,
      'originalUrl': originalUrl,
      'cachedAt': now.toIso8601String(),
      'expiration': expiration.toIso8601String(),
      'cacheDuration': cacheDuration.inMilliseconds,
    };

    await CacheService.setCache(
      'img_meta_$cacheKey',
      metadata,
      duration: _metadataCacheDuration,
    );
  }

  /// Get cache metadata
  Future<Map<String, dynamic>?> _getCacheMetadata(String cacheKey) async {
    return await CacheService.getCache<Map<String, dynamic>>(
      'img_meta_$cacheKey',
    );
  }

  /// Remove cached image and its metadata
  Future<void> _removeCachedImage(String cacheKey) async {
    // Remove from memory
    _memoryCache.remove(cacheKey);

    // Remove from disk (non-web only)
    if (!kIsWeb) {
      try {
        final cacheDir = await _getCacheDirectory();
        final file = File('${cacheDir.path}/$cacheKey.jpg');
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ ImageCache: Error removing disk cache for $cacheKey: $e');
        }
      }
    }

    // Remove metadata
    await CacheService.clearCache('img_meta_$cacheKey');

    if (kDebugMode) {
      print('🗑️ ImageCache: Removed $cacheKey');
    }
  }

  /// Clear all cached images
  Future<void> clearAllImages() async {
    // Clear memory cache
    _memoryCache.clear();

    // Clear disk cache (non-web only)
    if (!kIsWeb) {
      try {
        final cacheDir = await _getCacheDirectory();
        if (await cacheDir.exists()) {
          await for (final file in cacheDir.list()) {
            if (file is File && file.path.endsWith('.jpg')) {
              await file.delete();
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ ImageCache: Error clearing disk cache: $e');
        }
      }
    }

    // Clear metadata cache
    await CacheService.clearCachePattern('img_meta_');

    // Reset statistics
    _cacheHits = 0;
    _cacheMisses = 0;
    _networkRequests = 0;

    if (kDebugMode) {
      print('🧹 ImageCache: Cleared all cached images');
    }
  }

  /// Get cache size information
  Future<Map<String, dynamic>> getCacheSizeInfo() async {
    int diskCacheSize = 0;
    int diskCacheFiles = 0;
    int memoryCacheSize = 0;

    // Calculate memory cache size
    for (final imageData in _memoryCache.values) {
      memoryCacheSize += imageData.length;
    }

    // Calculate disk cache size (non-web only)
    if (!kIsWeb) {
      try {
        final cacheDir = await _getCacheDirectory();
        if (await cacheDir.exists()) {
          await for (final file in cacheDir.list()) {
            if (file is File && file.path.endsWith('.jpg')) {
              final stat = await file.stat();
              diskCacheSize += stat.size;
              diskCacheFiles++;
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ ImageCache: Error calculating cache size: $e');
        }
      }
    }

    return {
      'memoryFiles': _memoryCache.length,
      'memorySizeBytes': memoryCacheSize,
      'memorySizeMB': (memoryCacheSize / (1024 * 1024)).toStringAsFixed(2),
      'diskFiles': diskCacheFiles,
      'diskSizeBytes': diskCacheSize,
      'diskSizeMB': (diskCacheSize / (1024 * 1024)).toStringAsFixed(2),
      'totalSizeBytes': memoryCacheSize + diskCacheSize,
      'totalSizeMB': ((memoryCacheSize + diskCacheSize) / (1024 * 1024))
          .toStringAsFixed(2),
    };
  }

  /// Clean up expired cache entries
  Future<void> cleanupExpiredCache() async {
    int cleanedCount = 0;

    if (!kIsWeb) {
      try {
        final cacheDir = await _getCacheDirectory();
        if (await cacheDir.exists()) {
          await for (final file in cacheDir.list()) {
            if (file is File && file.path.endsWith('.jpg')) {
              final filename = file.path.split('/').last;
              final cacheKey = filename.replaceAll('.jpg', '');

              final metadata = await _getCacheMetadata(cacheKey);
              if (metadata != null) {
                final expiration = DateTime.parse(
                  metadata['expiration'] as String,
                );
                if (DateTime.now().isAfter(expiration)) {
                  await _removeCachedImage(cacheKey);
                  cleanedCount++;
                }
              } else {
                // No metadata found, remove the file
                await file.delete();
                cleanedCount++;
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ ImageCache: Error during cleanup: $e');
        }
      }
    }

    if (kDebugMode && cleanedCount > 0) {
      print('🧹 ImageCache: Cleaned up $cleanedCount expired cache entries');
    }
  }

  /// Preload images for a list of products
  Future<void> preloadProductImages(
    List<String> imageUrls, {
    int maxConcurrent = 3,
    Duration? cacheDuration,
  }) async {
    if (imageUrls.isEmpty) return;

    if (kDebugMode) {
      print('🚀 ImageCache: Preloading ${imageUrls.length} product images');
    }

    // Filter out already cached images
    final uncachedUrls = <String>[];
    for (final url in imageUrls) {
      if (!await isCached(url)) {
        uncachedUrls.add(url);
      }
    }

    if (uncachedUrls.isEmpty) {
      if (kDebugMode) {
        print('✅ ImageCache: All images already cached');
      }
      return;
    }

    if (kDebugMode) {
      print(
        '📥 ImageCache: Downloading ${uncachedUrls.length} uncached images',
      );
    }

    // Download images with concurrency limit
    final futures = <Future<void>>[];
    final semaphore = <bool>[];

    for (final url in uncachedUrls) {
      final future = () async {
        // Wait for available slot
        while (semaphore.length >= maxConcurrent) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        semaphore.add(true);
        try {
          await downloadAndCacheImage(url, cacheDuration: cacheDuration);
        } finally {
          semaphore.removeLast();
        }
      }();

      futures.add(future);
    }

    await Future.wait(futures);

    if (kDebugMode) {
      print('✅ ImageCache: Preloading completed');
    }
  }
}
