import 'package:flutter/material.dart';
import '../models/matcha_product.dart';
import 'category_icon.dart';

class ProductCard extends StatelessWidget {
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

  /// Extracts the price for the preferred currency from a multi-currency price string
  String? _extractPriceForCurrency(String? priceString, String currency) {
    if (priceString == null || priceString.isEmpty) return null;

    // Common currency symbols and patterns
    final Map<String, List<String>> currencyPatterns = {
      'EUR': ['€', 'EUR'],
      'USD': ['\$', 'USD'],
      'JPY': ['¥', '円', 'JPY'],
      'GBP': ['£', 'GBP'],
      'CHF': ['CHF'],
      'CAD': ['CAD'],
      'AUD': ['AUD'],
    };

    final patterns = currencyPatterns[currency] ?? [currency];

    // First, try to find currency-specific patterns in the full string
    for (final pattern in patterns) {
      // Look for complete price patterns with this currency
      // Pattern for currency symbol followed by or preceding numbers with decimal separators
      if (pattern == '€') {
        // Euro patterns: €15,99 or 15,99€ or €15.99 or 15.99€
        final euroMatch = RegExp(
          r'€\s*(\d+[.,]\d+)|(\d+[.,]\d+)\s*€',
        ).firstMatch(priceString);
        if (euroMatch != null) {
          final price = euroMatch.group(1) ?? euroMatch.group(2);
          return pattern == '€' && euroMatch.group(0)!.contains('€')
              ? euroMatch.group(0)!.trim()
              : '$price€';
        }
        // Also handle whole euro amounts: €15 or 15€
        final euroWholeMatch = RegExp(
          r'€\s*(\d+)|(\d+)\s*€',
        ).firstMatch(priceString);
        if (euroWholeMatch != null) {
          return euroWholeMatch.group(0)!.trim();
        }
      } else if (pattern == '\$') {
        // Dollar patterns: $15.99 or 15.99$ (less common)
        final dollarMatch = RegExp(
          r'\$\s*(\d+[.,]\d+)|(\d+[.,]\d+)\s*\$',
        ).firstMatch(priceString);
        if (dollarMatch != null) {
          return dollarMatch.group(0)!.trim();
        }
        // Also handle whole dollar amounts
        final dollarWholeMatch = RegExp(
          r'\$\s*(\d+)|(\d+)\s*\$',
        ).firstMatch(priceString);
        if (dollarWholeMatch != null) {
          return dollarWholeMatch.group(0)!.trim();
        }
      } else if (pattern == '¥') {
        // Yen patterns: ¥1000 or 1000¥ or ¥1,000
        final yenMatch = RegExp(
          r'¥\s*(\d+[.,]?\d*)|(\d+[.,]?\d*)\s*¥',
        ).firstMatch(priceString);
        if (yenMatch != null) {
          return yenMatch.group(0)!.trim();
        }
      } else if (pattern == '£') {
        // Pound patterns: £15.99 or 15.99£
        final poundMatch = RegExp(
          r'£\s*(\d+[.,]\d+)|(\d+[.,]\d+)\s*£',
        ).firstMatch(priceString);
        if (poundMatch != null) {
          return poundMatch.group(0)!.trim();
        }
        // Also handle whole pound amounts
        final poundWholeMatch = RegExp(
          r'£\s*(\d+)|(\d+)\s*£',
        ).firstMatch(priceString);
        if (poundWholeMatch != null) {
          return poundWholeMatch.group(0)!.trim();
        }
      }
    }

    // Fallback: split by pipe, semicolon, forward slash, and newlines (but NOT commas)
    // as commas are used as decimal separators in many currencies
    final parts = priceString.split(RegExp(r'[|;/\n\r]+'));

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      // Check if this part contains our currency
      for (final pattern in patterns) {
        if (trimmed.contains(pattern)) {
          return trimmed;
        }
      }
    }

    // If no specific currency found, return the first non-empty part
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    return priceString;
  }

  @override
  Widget build(BuildContext context) {
    final bool isUnavailable = !product.isInStock || product.isDiscontinued;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: isUnavailable ? 1 : 2,
      child: InkWell(
        onTap: onTap,
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
                        category: product.category,
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
                          product.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                isUnavailable
                                    ? Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.6)
                                    : null,
                            decoration:
                                product.isDiscontinued
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
                      if (onFavoriteToggle != null)
                        InkWell(
                          onTap: onFavoriteToggle,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 20,
                              color:
                                  isFavorite
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
                        product.site,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      if (product.price != null) ...[
                        Text(
                          _extractPriceForCurrency(
                                product.price!,
                                preferredCurrency ?? 'EUR',
                              ) ??
                              product.price!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            decoration:
                                product.isDiscontinued
                                    ? TextDecoration.lineThrough
                                    : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (product.category != null) ...[
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
                        product.category!,
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
                        'Last checked: ${_formatDateTime(product.lastChecked)}',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      if (product.firstSeen != product.lastChecked)
                        Text(
                          'Added ${_formatDateTime(product.firstSeen)}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                  if (extraInfo != null) ...[
                    const SizedBox(height: 8),
                    extraInfo!,
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

    if (product.isDiscontinued) {
      chipColor = Theme.of(context).colorScheme.outline;
      chipIcon = Icons.not_interested;
      chipText = 'Discontinued';
    } else if (product.isInStock) {
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
