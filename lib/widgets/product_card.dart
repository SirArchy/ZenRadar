import 'package:flutter/material.dart';
import '../models/matcha_product.dart';
import '../services/product_price_converter.dart';
import 'category_icon.dart';

class ProductCard extends StatefulWidget {
  final MatchaProduct product;
  final VoidCallback? onTap;
  final String? preferredCurrency;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final Widget? extraInfo;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.preferredCurrency = 'EUR',
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.extraInfo,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  String? _convertedPrice;
  bool _isConvertingPrice = false;

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

  @override
  Widget build(BuildContext context) {
    final bool isUnavailable =
        !widget.product.isInStock || widget.product.isDiscontinued;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: isUnavailable ? 1 : 2,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: isUnavailable ? 0.6 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color:
                  isUnavailable
                      ? Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.3)
                      : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CategoryIcon(
                        category: widget.product.category,
                        size: 32,
                        color:
                            isUnavailable
                                ? Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.4)
                                : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.product.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                isUnavailable
                                    ? Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.6)
                                    : null,
                            decoration:
                                widget.product.isDiscontinued
                                    ? TextDecoration.lineThrough
                                    : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(context),
                      const SizedBox(width: 8),
                      // Favorite button
                      if (widget.onFavoriteToggle != null)
                        InkWell(
                          onTap: widget.onFavoriteToggle,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              widget.isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 20,
                              color:
                                  widget.isFavorite
                                      ? Colors.red
                                      : Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.store,
                        size: 16,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.product.siteName ?? widget.product.site,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      if (widget.product.price != null) ...[
                        if (_isConvertingPrice)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Text(
                            _convertedPrice ?? widget.product.price!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration:
                                  widget.product.isDiscontinued
                                      ? TextDecoration.lineThrough
                                      : null,
                            ),
                          ),
                      ],
                    ],
                  ),
                  if (widget.product.category != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.product.category!,
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Last checked: ${_formatDateTime(widget.product.lastChecked)}',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      if (widget.product.firstSeen !=
                          widget.product.lastChecked)
                        Text(
                          'Added ${_formatDateTime(widget.product.firstSeen)}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                  if (widget.extraInfo != null) ...[
                    const SizedBox(height: 8),
                    widget.extraInfo!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    Color chipColor;
    IconData chipIcon;
    String chipText;

    if (widget.product.isDiscontinued) {
      chipColor = Theme.of(context).colorScheme.outline;
      chipIcon = Icons.not_interested;
      chipText = 'Discontinued';
    } else if (widget.product.isInStock) {
      chipColor = Theme.of(context).colorScheme.primary;
      chipIcon = Icons.check_circle;
      chipText = 'In Stock';
    } else {
      chipColor = Theme.of(context).colorScheme.error;
      chipIcon = Icons.cancel;
      chipText = 'Out of Stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            chipIcon,
            size: 14,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            chipText,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
