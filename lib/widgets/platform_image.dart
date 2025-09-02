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

    return processedUrl;
  }

  void _retry() {
    if (_retryCount < _maxRetries) {
      setState(() {
        _retryCount++;
        // Add a cache-busting parameter to force retry
        final processedUrl = _processImageUrl(widget.imageUrl);
        _currentUrl = '$processedUrl?retry=$_retryCount';
      });
    }
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
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Methods': 'GET',
              'User-Agent': 'Mozilla/5.0 (compatible; ZenRadar/1.0)',
              'Accept': 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
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
                    if (error.toString().contains('CORS') ||
                        error.toString().contains('statusCode: 0')) {
                      print(
                        '🖼️ Web image CORS error for ${widget.imageUrl}: Cross-origin request blocked. Retry attempt: $_retryCount',
                      );
                    } else if (error.toString().contains('EncodingError') ||
                        error.toString().contains('decode')) {
                      print(
                        '🖼️ Web image encoding error for ${widget.imageUrl}: Image file appears to be corrupted or in unsupported format',
                      );
                    } else {
                      print(
                        '🖼️ Web image load error for ${widget.imageUrl}: $error',
                      );
                    }
                  }

                  // Attempt retry for CORS issues
                  if ((error.toString().contains('CORS') ||
                          error.toString().contains('statusCode: 0')) &&
                      _retryCount < _maxRetries) {
                    // Delay retry to allow CORS settings to propagate
                    Future.delayed(const Duration(seconds: 2), _retry);
                  }

                  return widget.errorWidget!(context, widget.imageUrl, error);
                }
                : null,
      );
    }

    // On mobile platforms, use CachedNetworkImage for better performance
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      placeholder: widget.placeholder,
      errorWidget: widget.errorWidget,
      httpHeaders:
          widget.httpHeaders ??
          const {'User-Agent': 'Mozilla/5.0 (compatible; ZenRadar/1.0)'},
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
