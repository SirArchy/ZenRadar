import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A platform-aware image widget that handles web compatibility issues
/// while maintaining performance on mobile platforms
class PlatformImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // On web, use Image.network with enhanced error handling
    // This avoids the CachedNetworkImage encoding issues on web
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        headers: httpHeaders,
        loadingBuilder:
            placeholder != null
                ? (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return placeholder!(context, imageUrl);
                }
                : null,
        errorBuilder:
            errorWidget != null
                ? (context, error, stackTrace) {
                  // Enhanced error handling for web
                  if (kDebugMode) {
                    if (error.toString().contains('EncodingError') ||
                        error.toString().contains('decode')) {
                      print(
                        '🖼️ Web image encoding error for $imageUrl: Image file appears to be corrupted or in unsupported format',
                      );
                    } else {
                      print('🖼️ Web image load error for $imageUrl: $error');
                    }
                  }
                  return errorWidget!(context, imageUrl, error);
                }
                : null,
      );
    }

    // On mobile platforms, use CachedNetworkImage for better performance
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: placeholder,
      errorWidget: errorWidget,
      httpHeaders:
          httpHeaders ??
          const {'User-Agent': 'Mozilla/5.0 (compatible; ZenRadar/1.0)'},
      // Enhanced error handling for mobile
      errorListener: (exception) {
        if (kDebugMode) {
          if (exception.toString().contains('EncodingError') ||
              exception.toString().contains('decode')) {
            print('🖼️ Mobile image encoding error for $imageUrl: $exception');
          } else {
            print('🖼️ Mobile image error for $imageUrl: $exception');
          }
        }
      },
    );
  }

  /// Factory constructor for common use case with standard error handling
  factory PlatformImage.product({
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
