// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';

/// Utility class for processing image URLs to handle placeholders and platform-specific optimizations
class ImageUrlProcessor {
  /// Process image URL to replace placeholders and fix common issues
  static String processImageUrl(String url) {
    String processedUrl = url;

    // Check if URL has unprocessed placeholders
    bool hadPlaceholders = hasUnprocessedPlaceholders(url);

    // Replace {width} patterns with a reasonable default width
    processedUrl = processedUrl.replaceAll('{width}', '400');
    processedUrl = processedUrl.replaceAll('%7Bwidth%7D', '400');

    // Replace {height} patterns with a reasonable default height
    processedUrl = processedUrl.replaceAll('{height}', '400');
    processedUrl = processedUrl.replaceAll('%7Bheight%7D', '400');

    // Log URL processing for debugging on web
    if (kIsWeb && hadPlaceholders && kDebugMode) {
      print('🔧 ImageUrlProcessor: Processed $url -> $processedUrl');
    }

    // Fix doubled Firebase Storage domains
    if (processedUrl.contains('.firebasestorage.app.firebasestorage.app')) {
      processedUrl = processedUrl.replaceAll(
        '.firebasestorage.app.firebasestorage.app',
        '.firebasestorage.app',
      );
      if (kDebugMode) {
        print(
          '🔧 Fixed doubled Firebase Storage domain: $url -> $processedUrl',
        );
      }
    }
    // Ensure Firebase Storage URLs use the correct format
    else if (processedUrl.contains('storage.googleapis.com')) {
      if (!processedUrl.contains('.firebasestorage.app/')) {
        final regex = RegExp(r'storage\.googleapis\.com/([^/]+)/');
        final match = regex.firstMatch(processedUrl);

        if (match != null) {
          final bucketPart = match.group(1);
          if (bucketPart != null &&
              !bucketPart.endsWith('.firebasestorage.app')) {
            final newUrl = processedUrl.replaceFirst(
              'storage.googleapis.com/$bucketPart/',
              'storage.googleapis.com/$bucketPart.firebasestorage.app/',
            );

            if (kDebugMode) {
              print(
                '🔧 Added .firebasestorage.app suffix: $processedUrl -> $newUrl',
              );
            }
            processedUrl = newUrl;
          }
        }
      }
    }

    // On web, try to use HTTPS if available
    if (kIsWeb && processedUrl.startsWith('http://')) {
      final httpsUrl = processedUrl.replaceFirst('http://', 'https://');
      if (kDebugMode) {
        print(
          '🔒 Converting HTTP to HTTPS for web: $processedUrl -> $httpsUrl',
        );
      }
      processedUrl = httpsUrl;
    }

    // On web, try to use the more web-friendly Firebase Storage domain
    if (kIsWeb && processedUrl.contains('storage.googleapis.com')) {
      final webFriendlyUrl = processedUrl.replaceFirst(
        'storage.googleapis.com',
        'firebasestorage.googleapis.com',
      );
      if (kDebugMode) {
        print(
          '🌐 Using web-friendly Firebase Storage domain: $processedUrl -> $webFriendlyUrl',
        );
      }
      processedUrl = webFriendlyUrl;
    }

    return processedUrl;
  }

  /// Process a list of image URLs
  static List<String> processImageUrls(List<String> urls) {
    return urls.map((url) => processImageUrl(url)).toList();
  }

  /// Check if URL contains unprocessed placeholders
  static bool hasUnprocessedPlaceholders(String url) {
    return url.contains('{width}') ||
        url.contains('%7Bwidth%7D') ||
        url.contains('{height}') ||
        url.contains('%7Bheight%7D');
  }
}
