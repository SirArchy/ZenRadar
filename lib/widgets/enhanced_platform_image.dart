// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/image_cache_service.dart';
import '../services/image_url_processor.dart';

/// Enhanced cached image widget for product images
/// Uses ImageCacheService for optimized caching and reduced Firebase calls
class CachedProductImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext)? placeholder;
  final Widget Function(BuildContext)? errorWidget;
  final Map<String, String>? httpHeaders;
  final Duration? cacheDuration;

  const CachedProductImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.httpHeaders,
    this.cacheDuration,
  });

  @override
  State<CachedProductImage> createState() => _CachedProductImageState();
}

class _CachedProductImageState extends State<CachedProductImage> {
  bool _isLoading = true;
  bool _hasError = false;
  Uint8List? _imageData;
  int _retryCount = 0;
  static const int _maxRetries = 2;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resetState();
      _loadImage();
    }
  }

  void _resetState() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _imageData = null;
      _retryCount = 0;
    });
  }

  Future<void> _loadImage() async {
    if (!mounted) return;

    try {
      final imageCache = ImageCacheService.instance;

      // Try to get from cache first
      final cachedData = await imageCache.getCachedImage(widget.imageUrl);

      if (cachedData != null) {
        if (mounted) {
          setState(() {
            _imageData = cachedData;
            _isLoading = false;
            _hasError = false;
          });
        }
        return;
      }

      // Download and cache if not available
      final downloadedData = await imageCache.downloadAndCacheImage(
        widget.imageUrl,
        cacheDuration: widget.cacheDuration,
        headers: widget.httpHeaders,
      );

      if (downloadedData != null) {
        if (mounted) {
          setState(() {
            _imageData = downloadedData;
            _isLoading = false;
            _hasError = false;
          });
        }
      } else {
        _handleError('Failed to download image');
      }
    } catch (e) {
      _handleError(e.toString());
    }
  }

  void _handleError(String error) {
    if (kDebugMode) {
      print('🖼️ CachedProductImage error for ${widget.imageUrl}: $error');
    }

    // Retry logic
    if (_retryCount < _maxRetries) {
      _retryCount++;
      if (kDebugMode) {
        print(
          '🔄 CachedProductImage retry $_retryCount for ${widget.imageUrl}',
        );
      }

      // Retry after a delay
      Future.delayed(Duration(milliseconds: 500 * _retryCount), () {
        if (mounted) {
          _loadImage();
        }
      });
      return;
    }

    // Max retries reached, show error
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading placeholder
    if (_isLoading) {
      return widget.placeholder?.call(context) ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
    }

    // Show error widget
    if (_hasError || _imageData == null) {
      return widget.errorWidget?.call(context) ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported,
                  size: 32,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 4),
                Text(
                  'Image Error',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
    }

    // Show cached image
    return Image.memory(
      _imageData!,
      fit: widget.fit ?? BoxFit.cover,
      width: widget.width,
      height: widget.height,
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) {
          print('🖼️ Image.memory error for ${widget.imageUrl}: $error');
        }
        _handleError('Memory image error: $error');
        return widget.errorWidget?.call(context) ??
            Container(
              width: widget.width,
              height: widget.height,
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
      },
    );
  }
}

/// Enhanced platform image widget with integrated caching
/// Automatically chooses the best implementation based on platform and preferences
class PlatformImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final Map<String, String>? httpHeaders;
  final bool useEnhancedCache;
  final Duration? cacheDuration;

  const PlatformImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.httpHeaders,
    this.useEnhancedCache = true, // Default to enhanced cache
    this.cacheDuration,
  });

  String _processImageUrl(String url) {
    // Use the shared URL processor to ensure consistency
    return ImageUrlProcessor.processImageUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final processedUrl = _processImageUrl(imageUrl);

    // Use enhanced cache for product images (when enabled and on mobile)
    if (useEnhancedCache && !kIsWeb) {
      return CachedProductImage(
        imageUrl: processedUrl,
        fit: fit,
        width: width,
        height: height,
        placeholder:
            placeholder != null
                ? (context) => placeholder!(context, imageUrl)
                : null,
        errorWidget:
            errorWidget != null
                ? (context) =>
                    errorWidget!(context, imageUrl, 'Enhanced cache error')
                : null,
        httpHeaders: httpHeaders,
        cacheDuration: cacheDuration,
      );
    }

    // Fallback to original PlatformImage logic for web or when enhanced cache is disabled
    if (kIsWeb) {
      return Image.network(
        processedUrl,
        fit: fit,
        width: width,
        height: height,
        headers:
            httpHeaders ??
            {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.9',
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
        loadingBuilder:
            placeholder != null
                ? (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return placeholder!(context, imageUrl);
                }
                : null,
        errorBuilder:
            errorWidget != null
                ? (context, error, stackTrace) =>
                    errorWidget!(context, imageUrl, error)
                : null,
      );
    }

    // Use CachedNetworkImage for mobile when enhanced cache is disabled
    return CachedNetworkImage(
      imageUrl: processedUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: placeholder,
      errorWidget: (context, url, error) {
        return errorWidget?.call(context, imageUrl, error) ??
            Container(
              width: width,
              height: height,
              color: Colors.grey[200],
              child: const Icon(Icons.image_not_supported, color: Colors.grey),
            );
      },
      httpHeaders:
          httpHeaders ??
          const {
            'User-Agent': 'Mozilla/5.0 (compatible; ZenRadar/1.0)',
            'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
          },
      cacheKey: processedUrl,
      maxWidthDiskCache: 800,
      maxHeightDiskCache: 800,
    );
  }
}

/// Extension for PlatformImage factory constructors
extension PlatformImageFactory on PlatformImage {
  /// Factory constructor for product images with enhanced caching
  static PlatformImage product({
    required String imageUrl,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    required Widget Function(BuildContext) loadingWidget,
    required Widget Function(BuildContext) errorWidget,
    bool useEnhancedCache = true,
    Duration? cacheDuration,
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
      useEnhancedCache: useEnhancedCache,
      cacheDuration: cacheDuration,
    );
  }
}
