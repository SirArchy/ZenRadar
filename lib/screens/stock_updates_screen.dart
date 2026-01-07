// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/scan_activity.dart';
import '../models/matcha_product.dart';
import '../widgets/product_card_new.dart';

class StockUpdatesScreen extends StatelessWidget {
  final List<dynamic> updates;
  final ScanActivity scanActivity;
  final String? highlightProductId;
  const StockUpdatesScreen({
    super.key,
    required this.updates,
    required this.scanActivity,
    this.highlightProductId,
  });

  @override
  Widget build(BuildContext context) {
    // Separate stock updates and price updates
    final stockUpdates =
        updates.where((update) {
          final previousIsInStock = update['previousIsInStock'];
          final currentIsInStock =
              update['isInStock'] == 1 || update['isInStock'] == true;

          // Show products that are newly added and in stock
          if (previousIsInStock == null && currentIsInStock) {
            return true;
          }

          // Show products that went from out of stock to in stock
          if ((previousIsInStock == 0 || previousIsInStock == false) &&
              currentIsInStock) {
            return true;
          }

          return false;
        }).toList();

    final priceUpdates =
        updates.where((update) {
          return update['changeType'] == 'price';
        }).toList();

    final hasStockUpdates = stockUpdates.isNotEmpty;
    final hasPriceUpdates = priceUpdates.isNotEmpty;

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.productUpdates),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body:
          (!hasStockUpdates && !hasPriceUpdates)
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noProductUpdates,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.showsStockPriceChanges,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stock Updates Section
                    if (hasStockUpdates) ...[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.inventory,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${l10n.newStockArrivals} (${stockUpdates.length})',
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildProductGrid(stockUpdates, context),
                    ],

                    // Price Updates Section
                    if (hasPriceUpdates) ...[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.monetization_on,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${l10n.priceChanges} (${priceUpdates.length})',
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildProductGrid(priceUpdates, context),
                    ],
                  ],
                ),
              ),
    );
  }

  Widget _buildProductGrid(List<dynamic> productUpdates, BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isLargeScreen ? 3 : 2,
        childAspectRatio: isLargeScreen ? 0.65 : 0.6, // Responsive aspect ratio
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: productUpdates.length,
      itemBuilder: (context, index) {
        final update = productUpdates[index];
        return _buildProductCard(update, context);
      },
    );
  }

  Widget _buildProductCard(dynamic update, BuildContext context) {
    final product = MatchaProduct(
      id: update['productId'] ?? '',
      name: update['name'] ?? 'Unknown',
      normalizedName: update['name'] ?? 'Unknown',
      site: update['site'] ?? '',
      siteName: update['siteName'] ?? '',
      url: update['url'] ?? '',
      isInStock: update['isInStock'] == 1 || update['isInStock'] == true,
      lastChecked:
          DateTime.tryParse(update['timestamp'] ?? '') ?? DateTime.now(),
      firstSeen: DateTime.tryParse(update['timestamp'] ?? '') ?? DateTime.now(),
      price: update['price']?.toString(),
      priceValue:
          update['priceValue'] is double
              ? update['priceValue']
              : double.tryParse(update['priceValue']?.toString() ?? ''),
      currency: update['currency']?.toString(),
      imageUrl: update['imageUrl']?.toString(),
      description: update['description']?.toString(),
      category: update['category']?.toString(),
      weight:
          update['weight'] is int
              ? update['weight']
              : int.tryParse(update['weight']?.toString() ?? ''),
      metadata:
          update['metadata'] is Map<String, dynamic>
              ? update['metadata']
              : null,
    );

    // Create extra info widget for price changes
    Widget? extraInfo;
    final l10n = AppLocalizations.of(context)!;
    if (update['changeType'] == 'price' &&
        update['previousPrice'] != null &&
        update['previousPrice'].toString().isNotEmpty) {
      extraInfo = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.trending_up, size: 12, color: Colors.orange),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${l10n.was}: ${update['previousPrice']}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return ProductCard(
      product: product,
      preferredCurrency: product.currency,
      isFavorite: false,
      extraInfo: extraInfo,
      onTap: () async {
        if (product.url.isNotEmpty) {
          final uri = Uri.parse(product.url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.couldNotOpenProductPage)),
            );
          }
        }
      },
    );
  }
}
