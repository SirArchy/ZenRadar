// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import '../models/matcha_product.dart';
import '../services/product_price_converter.dart';
import 'category_icon.dart';
import 'enhanced_platform_image.dart';

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
            size: 24,
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
              size: 10,
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
          child: _buildLayout(),
        ),
      ),
    );
  }

  // Layout for narrow screens (phones)
  Widget _buildLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image section (top, aspect ratio based)
        AspectRatio(
          aspectRatio: 1.2, // 1.2:1 ratio (width:height)
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
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                      weight: 800,
                    ),
                  ),
                ),

              // Favorite button - top right
              if (widget.onFavoriteToggle != null)
                Positioned(right: 8, top: 8, child: _buildFavoriteButton()),
            ],
          ),
        ),

        // Content section (bottom) - with flexible layout
        Flexible(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product name
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Category badge
                if (widget.product.category != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CategoryIcon(
                          category: widget.product.category!,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.product.category!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // Site name
                Text(
                  widget.product.siteName ?? widget.product.site,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Extra info
                if (widget.extraInfo != null) ...[
                  const SizedBox(height: 6),
                  widget.extraInfo!,
                ],

                // Spacer to push price to bottom
                const Spacer(),

                // Price row (now at the bottom)
                if (widget.product.price != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
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
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(
            widget.isFavorite ? Icons.favorite : Icons.favorite_border,
            color: widget.isFavorite ? Colors.red : Colors.grey.shade600,
            size: 16,
          ),
        ),
      ),
    );
  }
}
