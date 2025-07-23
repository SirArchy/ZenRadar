// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/scan_activity.dart';
import '../models/matcha_product.dart';
import '../widgets/product_card.dart';

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
    final scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (highlightProductId != null) {
        final idx = updates.indexWhere(
          (u) => u['productId'] == highlightProductId,
        );
        if (idx != -1) {
          scrollController.animateTo(
            idx * 72.0, // Approximate item height
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Updates'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        controller: scrollController,
        itemCount: updates.length,
        itemBuilder: (context, index) {
          final update = updates[index];
          final isHighlighted =
              highlightProductId != null &&
              update['productId'] == highlightProductId;

          final product = MatchaProduct(
            id: update['productId'] ?? '',
            name: update['name'] ?? 'Unknown',
            normalizedName: update['name'] ?? 'Unknown',
            site: update['site'] ?? '',
            url: update['url'] ?? '',
            isInStock: update['isInStock'] == 1 || update['isInStock'] == true,
            lastChecked:
                DateTime.tryParse(update['timestamp'] ?? '') ?? DateTime.now(),
            firstSeen:
                DateTime.tryParse(update['timestamp'] ?? '') ?? DateTime.now(),
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

          final previousIsInStock = update['previousIsInStock'];
          String stockChangeText;
          Color stockChangeColor;

          if (previousIsInStock == null) {
            stockChangeText =
                product.isInStock
                    ? "First seen in stock"
                    : "First seen out of stock";
            stockChangeColor = product.isInStock ? Colors.green : Colors.red;
          } else if ((previousIsInStock == 0 || previousIsInStock == false) &&
              product.isInStock) {
            stockChangeText = "Back in Stock";
            stockChangeColor = Colors.green;
          } else if ((previousIsInStock == 1 || previousIsInStock == true) &&
              !product.isInStock) {
            stockChangeText = "Went Out of Stock";
            stockChangeColor = Colors.red;
          } else {
            stockChangeText =
                product.isInStock ? "Still in Stock" : "Still out of Stock";
            stockChangeColor = Colors.grey;
          }

          return Container(
            color: isHighlighted ? Colors.yellow.withAlpha(75) : null,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductCard(
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
                  extraInfo: Chip(
                    label: Text(stockChangeText),
                    backgroundColor: stockChangeColor.withAlpha(40),
                    labelStyle: TextStyle(
                      color: stockChangeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
