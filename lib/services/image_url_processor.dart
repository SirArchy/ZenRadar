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

    // On web, convert Firebase Storage URLs to proper download URL format
    if (kIsWeb &&
        (processedUrl.contains('storage.googleapis.com') ||
            processedUrl.contains('firebasestorage.googleapis.com'))) {
      try {
        final uri = Uri.parse(processedUrl);
        String bucketName;
        String filePath;

        // Handle different URL formats
        if (processedUrl.contains('storage.googleapis.com')) {
          // Format: https://storage.googleapis.com/bucket.firebasestorage.app/path
          final pathSegments = uri.pathSegments;
          if (pathSegments.isNotEmpty) {
            bucketName = pathSegments[0].replaceAll('.firebasestorage.app', '');
            if (pathSegments.length > 1) {
              filePath = pathSegments.skip(1).join('/');
            } else {
              throw Exception('No file path found');
            }
          } else {
            throw Exception('No path segments found');
          }
        } else if (processedUrl.contains(
          'firebasestorage.googleapis.com/v0/b/',
        )) {
          // Already in download URL format, just return it
          return processedUrl;
        } else {
          // Format: https://firebasestorage.googleapis.com/bucket.firebasestorage.app/path
          final pathSegments = uri.pathSegments;
          if (pathSegments.isNotEmpty) {
            bucketName = pathSegments[0].replaceAll('.firebasestorage.app', '');
            if (pathSegments.length > 1) {
              filePath = pathSegments.skip(1).join('/');
            } else {
              throw Exception('No file path found');
            }
          } else {
            throw Exception('No path segments found');
          }
        }

        // Create proper download URL with correct path encoding
        final pathSegments = filePath.split('/');
        final encodedPathSegments = pathSegments
            .map((segment) => Uri.encodeComponent(segment))
            .join('%2F');
        final downloadUrl =
            'https://firebasestorage.googleapis.com/v0/b/$bucketName/o/$encodedPathSegments?alt=media';

        if (kDebugMode) {
          print(
            '🌐 Converting to Firebase Storage download URL: $processedUrl -> $downloadUrl',
          );
        }
        processedUrl = downloadUrl;
      } catch (e) {
        if (kDebugMode) {
          print('🚨 Failed to convert Firebase Storage URL: $e');
          print('🚨 Original URL: $processedUrl');
        }
        // If conversion fails, try alternative approaches
        if (processedUrl.contains('storage.googleapis.com')) {
          // Try simple domain replacement as fallback
          final fallbackUrl = processedUrl.replaceFirst(
            'storage.googleapis.com',
            'firebasestorage.googleapis.com',
          );
          if (kDebugMode) {
            print(
              '🌐 Using fallback domain replacement: $processedUrl -> $fallbackUrl',
            );
          }
          processedUrl = fallbackUrl;
        } else {
          // For URLs that are already firebasestorage.googleapis.com but not in proper format
          // Try to make them publicly accessible by appending ?alt=media if not present
          if (!processedUrl.contains('?alt=media') &&
              !processedUrl.contains('/v0/b/')) {
            final mediaUrl = '$processedUrl?alt=media';
            if (kDebugMode) {
              print(
                '🌐 Adding alt=media parameter: $processedUrl -> $mediaUrl',
              );
            }
            processedUrl = mediaUrl;
          }
        }
      }
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
