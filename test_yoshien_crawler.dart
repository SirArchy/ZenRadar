// ignore_for_file: avoid_print

import 'package:zenradar/services/crawler_service.dart';

void main() async {
  print('=== Testing Updated Yoshi En Crawler ===');

  final crawlerService = CrawlerService();

  try {
    final products = await crawlerService.crawlSite('yoshien');

    print('✅ Found ${products.length} products on Yoshi En');

    if (products.isNotEmpty) {
      print('\nFirst 5 products:');
      for (int i = 0; i < 5 && i < products.length; i++) {
        final product = products[i];
        print(
          '${i + 1}. "${product.name}" - ${product.price} - ${product.isInStock ? '✅ In Stock' : '❌ Out of Stock'}',
        );
        print('   URL: ${product.url}');
      }
    } else {
      print('❌ No products found');
    }
  } catch (e) {
    print('❌ Error testing Yoshi En crawler: $e');
  }
}
