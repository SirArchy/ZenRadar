// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
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
    // Filter updates to only show products that are newly added or came back in stock
    final filteredUpdates =
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

          // Don't show products that went out of stock or stayed the same
          return false;
        }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Stock Arrivals'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body:
          filteredUpdates.isEmpty
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No new stock arrivals',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This shows products that are newly discovered\nor came back in stock.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
              : GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      MediaQuery.of(context).size.width > 600
                          ? 3
                          : 2, // 3 columns on wide screens, 2 on narrow
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                padding: const EdgeInsets.all(8),
                itemCount: filteredUpdates.length,
                itemBuilder: (context, index) {
                  final update = filteredUpdates[index];

                  final product = MatchaProduct(
                    id: update['productId'] ?? '',
                    name: update['name'] ?? 'Unknown',
                    normalizedName: update['name'] ?? 'Unknown',
                    site: update['site'] ?? '',
                    url: update['url'] ?? '',
                    isInStock:
                        update['isInStock'] == 1 || update['isInStock'] == true,
                    lastChecked:
                        DateTime.tryParse(update['timestamp'] ?? '') ??
                        DateTime.now(),
                    firstSeen:
                        DateTime.tryParse(update['timestamp'] ?? '') ??
                        DateTime.now(),
                    price: update['price']?.toString(),
                    priceValue:
                        update['priceValue'] is double
                            ? update['priceValue']
                            : double.tryParse(
                              update['priceValue']?.toString() ?? '',
                            ),
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

                  return ProductCard(
                    product: product,
                    preferredCurrency: product.currency,
                    isFavorite: false,
                    onTap: () async {
                      if (product.url.isNotEmpty) {
                        final uri = Uri.parse(product.url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open product page'),
                            ),
                          );
                        }
                      }
                    },
                  );
                },
              ),
    );
  }
}
