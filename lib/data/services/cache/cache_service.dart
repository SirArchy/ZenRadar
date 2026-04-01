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

      if (kDebugMode) {}
    } catch (e) {
      if (kDebugMode) {}
    }
  }

  /// Retrieve data from cache if not expired
  static Future<T?> getCache<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(key);

      if (cachedString == null) {
        if (kDebugMode) {}
        return null;
      }

      final cacheData = json.decode(cachedString) as Map<String, dynamic>;
      final expiration = DateTime.parse(cacheData['expiration'] as String);
      final now = DateTime.now();

      if (now.isAfter(expiration)) {
        // Cache expired, remove it
        await prefs.remove(key);
        if (kDebugMode) {}
        return null;
      }

      if (kDebugMode) {
        DateTime.parse(cacheData['timestamp'] as String);
      }

      return cacheData['data'] as T;
    } catch (e) {
      if (kDebugMode) {}
      return null;
    }
  }

  /// Clear specific cache entry
  static Future<void> clearCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);

      if (kDebugMode) {}
    } catch (e) {
      if (kDebugMode) {}
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

      if (kDebugMode) {}
    } catch (e) {
      if (kDebugMode) {}
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
