// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import '../models/matcha_product.dart';
import '../services/product_price_converter.dart';
import 'category_icon.dart';
import 'platform_image.dart';

class ProductCard extends StatefulWidget {
  final MatchaProduct product;
  final VoidCallback? onTap;
  final String? preferredCurrency;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final Widget? extraInfo;
  final bool hideLastChecked;

  const ProductCard({
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
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  String? _convertedPrice;
  bool _isConvertingPrice = false;
  static final Set<String> _loggedImageErrors = <String>{};

  @override
  void initState() {
    super.initState();
    _convertPrice();
  }

  @override
  void didUpdateWidget(ProductCard oldWidget) {
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
      height: double.infinity,
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
            size: 32,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 4),
          Text(
            'No Image',
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

  Widget _buildImageLoading(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
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
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.broken_image,
              size: 12,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isUnavailable =
        !widget.product.isInStock || widget.product.isDiscontinued;

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: isUnavailable ? 1 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: isUnavailable ? 0.7 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top section: Image with favorite button (about 50% of height)
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    // Product Image
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
                                      print(
                                        'Platform image error for $url: Using fallback widget',
                                      );
                                    }
                                    return _buildImageErrorFallback(
                                      context,
                                      url,
                                    );
                                  },
                                )
                                : _buildPlaceholderBackground(context),
                      ),
                    ),

                    // Favorite button - top right corner
                    if (widget.onFavoriteToggle != null)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
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
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Icon(
                                widget.isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color:
                                    widget.isFavorite
                                        ? Colors.red
                                        : Colors.grey.shade600,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Middle section: Details list (about 50% of height)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top details
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Name (bold, larger font)
                          Text(
                            widget.product.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              decoration:
                                  widget.product.isDiscontinued
                                      ? TextDecoration.lineThrough
                                      : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          // Product Website (smaller, link-style text)
                          Text(
                            widget.product.siteName ?? widget.product.site,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          // Product Category (badge style)
                          if (widget.product.category != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CategoryIcon(
                                    category: widget.product.category,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.product.category!,
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),

                          // Stock Status (with icons)
                          Row(
                            children: [
                              Icon(
                                widget.product.isDiscontinued
                                    ? Icons.not_interested
                                    : widget.product.isInStock
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                size: 14,
                                color:
                                    widget.product.isDiscontinued
                                        ? Colors.grey
                                        : widget.product.isInStock
                                        ? Colors.green
                                        : Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.product.isDiscontinued
                                    ? 'Discontinued'
                                    : widget.product.isInStock
                                    ? 'In Stock'
                                    : 'Out of Stock',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      widget.product.isDiscontinued
                                          ? Colors.grey
                                          : widget.product.isInStock
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Last Updated (smaller, gray text)
                          if (!widget.hideLastChecked)
                            Text(
                              'Updated ${_formatDateTime(widget.product.lastChecked)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                        ],
                      ),

                      // Bottom section: Price (bold, larger font, left-aligned)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.product.price != null)
                            Row(
                              children: [
                                if (_isConvertingPrice)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  Text(
                                    _convertedPrice ?? widget.product.price!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                              ],
                            ),

                          if (widget.extraInfo != null) ...[
                            const SizedBox(height: 6),
                            widget.extraInfo!,
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
