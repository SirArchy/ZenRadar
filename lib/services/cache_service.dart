import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Generic cache service for storing and retrieving data with expiration
class CacheService {
  static const Duration _defaultCacheDuration = Duration(minutes: 30);

  /// Store data in cache with optional custom expiration
  static Future<void> setCache(
    String key,
    dynamic data, {
    Duration? duration,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final expiration = now.add(duration ?? _defaultCacheDuration);

      final cacheData = {
        'data': data,
        'timestamp': now.toIso8601String(),
        'expiration': expiration.toIso8601String(),
      };

      await prefs.setString(key, json.encode(cacheData));

      if (kDebugMode) {
        print('Cache SET: $key (expires: ${expiration.toString()})');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Cache SET error for $key: $e');
      }
    }
  }

  /// Retrieve data from cache if not expired
  static Future<T?> getCache<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(key);

      if (cachedString == null) {
        if (kDebugMode) {
          print('Cache MISS: $key (not found)');
        }
        return null;
      }

      final cacheData = json.decode(cachedString) as Map<String, dynamic>;
      final expiration = DateTime.parse(cacheData['expiration'] as String);
      final now = DateTime.now();

      if (now.isAfter(expiration)) {
        // Cache expired, remove it
        await prefs.remove(key);
        if (kDebugMode) {
          print('⏰ Cache EXPIRED: $key (expired: ${expiration.toString()})');
        }
        return null;
      }

      if (kDebugMode) {
        final timestamp = DateTime.parse(cacheData['timestamp'] as String);
        print('Cache HIT: $key (cached: ${timestamp.toString()})');
      }

      return cacheData['data'] as T;
    } catch (e) {
      if (kDebugMode) {
        print('Cache GET error for $key: $e');
      }
      return null;
    }
  }

  /// Clear specific cache entry
  static Future<void> clearCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);

      if (kDebugMode) {
        print('🗑️ Cache CLEAR: $key');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Cache CLEAR error for $key: $e');
      }
    }
  }

  /// Clear all cache entries matching a pattern
  static Future<void> clearCachePattern(String pattern) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.contains(pattern));

      for (final key in keys) {
        await prefs.remove(key);
      }

      if (kDebugMode) {
        print('🗑️ Cache CLEAR PATTERN: $pattern (${keys.length} items)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Cache CLEAR PATTERN error for $pattern: $e');
      }
    }
  }

  /// Check if cache entry exists and is valid
  static Future<bool> isCacheValid(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(key);

      if (cachedString == null) return false;

      final cacheData = json.decode(cachedString) as Map<String, dynamic>;
      final expiration = DateTime.parse(cacheData['expiration'] as String);
      final now = DateTime.now();

      return now.isBefore(expiration);
    } catch (e) {
      return false;
    }
  }

  /// Get cache info (for debugging)
  static Future<Map<String, dynamic>?> getCacheInfo(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(key);

      if (cachedString == null) return null;

      final cacheData = json.decode(cachedString) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cacheData['timestamp'] as String);
      final expiration = DateTime.parse(cacheData['expiration'] as String);
      final now = DateTime.now();

      return {
        'key': key,
        'cached_at': timestamp.toIso8601String(),
        'expires_at': expiration.toIso8601String(),
        'is_valid': now.isBefore(expiration),
        'age_minutes': now.difference(timestamp).inMinutes,
        'expires_in_minutes': expiration.difference(now).inMinutes,
      };
    } catch (e) {
      return null;
    }
  }
}
