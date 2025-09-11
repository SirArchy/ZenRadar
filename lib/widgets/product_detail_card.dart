// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/matcha_product.dart';
import '../services/product_price_converter.dart';
import 'category_icon.dart';
import 'enhanced_platform_image.dart';

class ProductDetailCard extends StatefulWidget {
  final MatchaProduct product;
  final VoidCallback? onTap;
  final String? preferredCurrency;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final Widget? extraInfo;
  final bool hideLastChecked;

  const ProductDetailCard({
    super.key,
    required this.product,
    this.onTap,
    this.preferredCurrency = 'EUR',
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.extraInfo,
    this.hideLastChecked = false,
  });

  @override
  State<ProductDetailCard> createState() => _ProductDetailCardState();
}

class _ProductDetailCardState extends State<ProductDetailCard> {
  String? _convertedPrice;
  bool _isConvertingPrice = false;
  static final Set<String> _loggedImageErrors = <String>{};

  @override
  void initState() {
    super.initState();
    _convertPrice();
  }

  @override
  void didUpdateWidget(ProductDetailCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferredCurrency != widget.preferredCurrency ||
        oldWidget.product.price != widget.product.price) {
      _convertPrice();
    }
  }

  Future<void> _convertPrice() async {
    if (widget.product.price == null || widget.preferredCurrency == null) {
      return;
    }

    setState(() {
      _isConvertingPrice = true;
    });

    try {
      final convertedPrice = await ProductPriceConverter.instance.convertPrice(
        rawPrice: widget.product.price,
        productCurrency: widget.product.currency,
        preferredCurrency: widget.preferredCurrency!,
        siteKey: widget.product.site.toLowerCase().replaceAll(' ', '-'),
        priceValue: widget.product.priceValue,
      );

      if (mounted) {
        setState(() {
          _convertedPrice = convertedPrice;
          _isConvertingPrice = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _convertedPrice = widget.product.price; // Fallback to original
          _isConvertingPrice = false;
        });
      }
    }
  }

  Widget _buildPlaceholderBackground(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 48,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'No Image Available',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageLoading(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildImageErrorFallback(BuildContext context, String url) {
    return Stack(
      children: [
        _buildPlaceholderBackground(context),
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.broken_image,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// Launches a URL in the default browser
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isUnavailable =
        !widget.product.isInStock || widget.product.isDiscontinued;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Card(
      margin: const EdgeInsets.all(0),
      elevation: isUnavailable ? 1 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: widget.onTap ?? () => _launchUrl(widget.product.url),
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: isUnavailable ? 0.7 : 1.0,
          child: isWideScreen ? _buildWideLayout() : _buildNarrowLayout(),
        ),
      ),
    );
  }

  // Layout for wide screens (tablets/desktop)
  Widget _buildWideLayout() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image section (left side, fixed width)
          SizedBox(
            width: 200,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child:
                        widget.product.imageUrl != null
                            ? PlatformImageFactory.product(
                              imageUrl: widget.product.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              loadingWidget:
                                  (context) => _buildImageLoading(context),
                              errorWidget: (context) {
                                final url = widget.product.imageUrl!;
                                if (!_loggedImageErrors.contains(url)) {
                                  _loggedImageErrors.add(url);
                                  print('Failed to load product image: $url');
                                }
                                return _buildImageErrorFallback(context, url);
                              },
                            )
                            : _buildPlaceholderBackground(context),
                  ),
                ),

                // Out of Stock X overlay - center of image
                if (!widget.product.isInStock && !widget.product.isDiscontinued)
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 48,
                        weight: 800,
                      ),
                    ),
                  ),

                // Favorite button - top left of image
                if (widget.onFavoriteToggle != null)
                  Positioned(left: 12, top: 12, child: _buildFavoriteButton()),
              ],
            ),
          ),

          // Content section (right side, flexible)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Name and open link button
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.product.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            decoration:
                                widget.product.isDiscontinued
                                    ? TextDecoration.lineThrough
                                    : null,
                          ),
                          maxLines: 1, // Changed from 2 to 1 for ellipsis
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildOpenLinkButton(),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Category badge (moved up, right under name)
                  if (widget.product.category != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, // Bigger padding
                        vertical: 8, // Bigger padding
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(
                          20,
                        ), // Bigger radius
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CategoryIcon(
                            category: widget.product.category!,
                            size: 18, // Bigger icon
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.product.category!,
                            style: TextStyle(
                              fontSize: 16, // Bigger text
                              fontWeight: FontWeight.w600,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Site name (moved below category)
                  Text(
                    widget.product.siteName ?? widget.product.site,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12), // Reduced space
                  // Price and Last Updated row
                  Row(
                    children: [
                      // Price (left side)
                      if (widget.product.price != null) ...[
                        if (_isConvertingPrice)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Expanded(
                            child: Text(
                              _convertedPrice ?? widget.product.price!,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                      ],

                      // Last Updated (right side)
                      if (!widget.hideLastChecked &&
                          widget.product.price != null) ...[
                        const SizedBox(width: 16),
                        Text(
                          _formatDateTime(widget.product.lastChecked),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Extra info
                  if (widget.extraInfo != null) ...[
                    const SizedBox(height: 12),
                    widget.extraInfo!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Layout for narrow screens (phones)
  Widget _buildNarrowLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Image section (top, fixed height)
        SizedBox(
          height: 200,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child:
                      widget.product.imageUrl != null
                          ? PlatformImageFactory.product(
                            imageUrl: widget.product.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            loadingWidget:
                                (context) => _buildImageLoading(context),
                            errorWidget: (context) {
                              final url = widget.product.imageUrl!;
                              if (!_loggedImageErrors.contains(url)) {
                                _loggedImageErrors.add(url);
                                print('Failed to load product image: $url');
                              }
                              return _buildImageErrorFallback(context, url);
                            },
                          )
                          : _buildPlaceholderBackground(context),
                ),
              ),

              // Out of Stock X overlay - center of image
              if (!widget.product.isInStock && !widget.product.isDiscontinued)
                Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 42,
                      weight: 800,
                    ),
                  ),
                ),

              // Favorite button - top left
              if (widget.onFavoriteToggle != null)
                Positioned(left: 12, top: 12, child: _buildFavoriteButton()),
              // Open link button - top right
              Positioned(right: 12, top: 12, child: _buildOpenLinkButton()),
            ],
          ),
        ),

        // Content section (bottom)
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product name
              Text(
                widget.product.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                  decoration:
                      widget.product.isDiscontinued
                          ? TextDecoration.lineThrough
                          : null,
                ),
                maxLines: 1, // Changed from 2 to 1 for ellipsis
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Category badge (moved up, right under name)
              if (widget.product.category != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, // Bigger padding
                    vertical: 6, // Bigger padding
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(18), // Bigger radius
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CategoryIcon(
                        category: widget.product.category!,
                        size: 16, // Bigger icon
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.product.category!,
                        style: TextStyle(
                          fontSize: 14, // Bigger text
                          fontWeight: FontWeight.w600,
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Site name (moved below category)
              Text(
                widget.product.siteName ?? widget.product.site,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8), // Reduced space
              // Price and Last Updated row
              Row(
                children: [
                  // Price (left side)
                  if (widget.product.price != null) ...[
                    if (_isConvertingPrice)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Expanded(
                        child: Text(
                          _convertedPrice ?? widget.product.price!,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],

                  // Last Updated (right side)
                  if (!widget.hideLastChecked &&
                      widget.product.price != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      _formatDateTime(widget.product.lastChecked),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),

              // Extra info
              if (widget.extraInfo != null) ...[
                const SizedBox(height: 8),
                widget.extraInfo!,
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: widget.onFavoriteToggle,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            widget.isFavorite ? Icons.favorite : Icons.favorite_border,
            color: widget.isFavorite ? Colors.red : Colors.grey.shade600,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildOpenLinkButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _launchUrl(widget.product.url),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            Icons.open_in_new,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
