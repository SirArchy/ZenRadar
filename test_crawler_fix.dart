// ignore_for_file: avoid_print

import 'dart:io';
import 'lib/services/crawler_service.dart';
import 'lib/services/database_service.dart';

void main() async {
  print('🧪 Testing Matcha Kāru Crawler Fix...');

  try {
    // Initialize database
    await DatabaseService.platformService.initDatabase();
    print('✅ Database initialized');

    // Test crawling Matcha Kāru specifically
    final crawler = CrawlerService.instance;
    final products = await crawler.crawlSite('matcha-karu');

    print('✅ Crawled Matcha Kāru, found ${products.length} products');

    // Show first few products
    for (int i = 0; i < (products.length > 3 ? 3 : products.length); i++) {
      final product = products[i];
      print('Product ${i + 1}:');
      print('  Name: "${product.name}"');
      print('  Price: "${product.price}"');
      print('  Site: "${product.site}"');
      print('  Link: "${product.url}"');
      print('  In Stock: ${product.isInStock}');
    }

    print('\n🎉 Test completed successfully!');
  } catch (e) {
    print('❌ Error during test: $e');
    exit(1);
  }
}
