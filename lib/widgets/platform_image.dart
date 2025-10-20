// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A platform-aware image widget that handles web compatibility issues
/// while maintaining performance on mobile platforms
class PlatformImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final Map<String, String>? httpHeaders;

  const PlatformImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.httpHeaders,
  });

  @override
  State<PlatformImage> createState() => _PlatformImageState();
}

class _PlatformImageState extends State<PlatformImage> {
  int _retryCount = 0;
  static const int _maxRetries = 2;
  late String _currentUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = _processImageUrl(widget.imageUrl);

    if (kDebugMode && widget.imageUrl != _currentUrl) {
      print('🔍 URL Processing: ${widget.imageUrl} -> $_currentUrl');
    }
  }

  String _processImageUrl(String url) {
    // Replace common placeholder patterns in image URLs
    String processedUrl = url;

    // Replace {width} patterns with a reasonable default width
    processedUrl = processedUrl.replaceAll('{width}', '400');
    processedUrl = processedUrl.replaceAll('%7Bwidth%7D', '400');

    // Replace {height} patterns with a reasonable default height
    processedUrl = processedUrl.replaceAll('{height}', '400');
    processedUrl = processedUrl.replaceAll('%7Bheight%7D', '400');

    // Check if it's already a valid Firebase Storage download URL
    if (processedUrl.contains('firebasestorage.googleapis.com/v0/b/') &&
        processedUrl.contains('/o/') &&
        processedUrl.contains('?alt=media')) {
      // Check if the bucket name has the correct .firebasestorage.app suffix
      final regex = RegExp(r'firebasestorage\.googleapis\.com/v0/b/([^/]+)/o/');
      final match = regex.firstMatch(processedUrl);

      if (match != null) {
        final bucketName = match.group(1);
        if (bucketName != null &&
            !bucketName.endsWith('.firebasestorage.app')) {
          // Fix missing .firebasestorage.app suffix
          final correctedUrl = processedUrl.replaceFirst(
            'firebasestorage.googleapis.com/v0/b/$bucketName/',
            'firebasestorage.googleapis.com/v0/b/$bucketName.firebasestorage.app/',
          );

          if (kDebugMode) {
            print(
              '🔧 PlatformImage: Fixed missing .firebasestorage.app suffix: $processedUrl -> $correctedUrl',
            );
          }
          return correctedUrl;
        }
      }

      // Already in correct download URL format, no processing needed
      if (kDebugMode) {
        print(
          '✅ URL already in correct Firebase Storage format: $processedUrl',
        );
      }
      return processedUrl;
    }

    // Fix doubled Firebase Storage domains (e.g., firebasestorage.app.firebasestorage.app)
    // This must be first to handle URLs that already have the doubled domain
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
    // Only process if it wasn't already fixed above
    else if (processedUrl.contains('storage.googleapis.com') &&
        !processedUrl.contains('firebasestorage.googleapis.com')) {
      // Check if the URL already has the correct .firebasestorage.app format
      // Look for pattern: storage.googleapis.com/bucket-name.firebasestorage.app/
      if (!processedUrl.contains('.firebasestorage.app/')) {
        // Fix potential missing .firebasestorage.app in Firebase Storage URLs
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
      } else {
        if (kDebugMode) {
          print(
            '✅ URL already has correct Firebase Storage format: $processedUrl',
          );
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

    return processedUrl;
  }

  @override
  Widget build(BuildContext context) {
    // On web, use Image.network with enhanced error handling and CORS headers
    // This avoids the CachedNetworkImage encoding issues on web
    if (kIsWeb) {
      return Image.network(
        _currentUrl,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        headers:
            widget.httpHeaders ??
            {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.9',
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
        loadingBuilder:
            widget.placeholder != null
                ? (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return widget.placeholder!(context, widget.imageUrl);
                }
                : null,
        errorBuilder:
            widget.errorWidget != null
                ? (context, error, stackTrace) {
                  // Enhanced error handling for web with CORS detection and retry
                  if (kDebugMode) {
                    print('🖼️ Failed to load product image: $_currentUrl');
                    print('🖼️ Error details: $error');
                    if (stackTrace != null) {
                      print('🖼️ Stack trace: $stackTrace');
                    }

                    if (error.toString().contains('CORS') ||
                        error.toString().contains('statusCode: 0') ||
                        error.toString().contains('Cross-Origin') ||
                        error.toString().contains('cross-origin')) {
                      print(
                        '🖼️ Web image CORS error for ${widget.imageUrl}: Cross-origin request blocked. Retry attempt: $_retryCount',
                      );
                    } else if (error.toString().contains('EncodingError') ||
                        error.toString().contains('decode')) {
                      print(
                        '🖼️ Web image encoding error for ${widget.imageUrl}: Image file appears to be corrupted or in unsupported format',
                      );
                    } else if (error.toString().contains('404') ||
                        error.toString().contains(
                          'NetworkImageLoadException',
                        )) {
                      print(
                        '🖼️ Web image load error for ${widget.imageUrl}: Image not found or network error',
                      );
                    } else {
                      print(
                        '🖼️ Web image load error for ${widget.imageUrl}: $error',
                      );
                    }
                  }

                  // For any loading issues on web, try using a different approach
                  if (_retryCount < _maxRetries) {
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        setState(() {
                          _retryCount++;

                          if (_retryCount == 1) {
                            // First retry: Add cache busting parameter
                            final timestamp =
                                DateTime.now().millisecondsSinceEpoch;
                            _currentUrl =
                                '${_processImageUrl(widget.imageUrl)}?t=$timestamp';
                            if (kDebugMode) {
                              print(
                                '🔄 Retry $_retryCount with cache busting: $_currentUrl',
                              );
                            }
                          } else {
                            // Second retry: Try removing any double domains that might still exist
                            String fallbackUrl = _processImageUrl(
                              widget.imageUrl,
                            );
                            // Extra safety check for double domains
                            if (fallbackUrl.contains(
                              '.firebasestorage.app.firebasestorage.app',
                            )) {
                              fallbackUrl = fallbackUrl.replaceAll(
                                '.firebasestorage.app.firebasestorage.app',
                                '.firebasestorage.app',
                              );
                            }
                            final timestamp =
                                DateTime.now().millisecondsSinceEpoch;
                            _currentUrl =
                                '$fallbackUrl?v=$_retryCount&t=$timestamp';
                            if (kDebugMode) {
                              print(
                                '🔄 Retry $_retryCount with cleaned URL: $_currentUrl',
                              );
                            }
                          }
                        });
                      }
                    });

                    // Return a loading indicator while retrying
                    return widget.placeholder?.call(context, widget.imageUrl) ??
                        const CircularProgressIndicator(strokeWidth: 2);
                  }

                  return widget.errorWidget!(context, widget.imageUrl, error);
                }
                : null,
      );
    }

    // On mobile platforms, use CachedNetworkImage for better performance
    return CachedNetworkImage(
      imageUrl: _processImageUrl(widget.imageUrl), // Process URL on mobile too
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      placeholder: widget.placeholder,
      errorWidget: (context, url, error) {
        if (kDebugMode) {
          if (error.toString().contains('404') ||
              error.toString().contains('Invalid statusCode: 404')) {
            print(
              '🖼️ Mobile image 404 error for ${widget.imageUrl}: Image not found. Processed URL: ${_processImageUrl(widget.imageUrl)}',
            );
          } else if (error.toString().contains('EncodingError') ||
              error.toString().contains('decode')) {
            print(
              '🖼️ Mobile image encoding error for ${widget.imageUrl}: Image file appears to be corrupted or in unsupported format',
            );
          } else {
            print('🖼️ Mobile image error for ${widget.imageUrl}: $error');
          }
        }

        // Attempt to use fallback widget or return default
        if (widget.errorWidget != null) {
          return widget.errorWidget!(context, widget.imageUrl, error);
        }

        return Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[200],
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        );
      },
      httpHeaders:
          widget.httpHeaders ??
          const {
            'User-Agent': 'Mozilla/5.0 (compatible; ZenRadar/1.0)',
            'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
          },
      // Enhanced caching settings for Firebase Storage
      cacheKey: _processImageUrl(
        widget.imageUrl,
      ), // Use processed URL as cache key
      maxWidthDiskCache: 800,
      maxHeightDiskCache: 800,
      // Enhanced error handling for mobile
      errorListener: (exception) {
        if (kDebugMode) {
          if (exception.toString().contains('EncodingError') ||
              exception.toString().contains('decode')) {
            print(
              '🖼️ Mobile image encoding error for ${widget.imageUrl}: $exception',
            );
          } else {
            print('🖼️ Mobile image error for ${widget.imageUrl}: $exception');
            print(
              '🖼️ Platform image error for ${widget.imageUrl}: Using fallback widget',
            );
          }
        }
      },
    );
  }
}

/// Extension for PlatformImage factory constructors
extension PlatformImageFactory on PlatformImage {
  /// Factory constructor for common use case with standard error handling
  static PlatformImage product({
    required String imageUrl,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    required Widget Function(BuildContext) loadingWidget,
    required Widget Function(BuildContext) errorWidget,
  }) {
    return PlatformImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, url) => loadingWidget(context),
      errorWidget: (context, url, error) => errorWidget(context),
      httpHeaders: const {
        'User-Agent': 'Mozilla/5.0 (compatible; ZenRadar/1.0)',
        'Accept': 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      },
    );
  }
}
