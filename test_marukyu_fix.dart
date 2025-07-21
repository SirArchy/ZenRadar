// Test the fixed Marukyu crawler
// ignore_for_file: avoid_print

import 'lib/services/crawler_service.dart';

void main() async {
  print('🧪 Testing fixed Marukyu crawler...');

  try {
    final crawler = CrawlerService.instance;

    print('📡 Starting crawl of Marukyu-Koyamaen...');
    final products = await crawler.crawlSite('marukyu');

    print('\n📊 Crawl Results:');
    print('  📦 Total products found: ${products.length}');

    if (products.isNotEmpty) {
      int inStockCount = products.where((p) => p.isInStock).length;
      int outOfStockCount = products.where((p) => !p.isInStock).length;

      print('  ✅ In stock: $inStockCount');
      print('  ❌ Out of stock: $outOfStockCount');

      print('\n📋 Sample products:');
      for (int i = 0; i < products.length && i < 5; i++) {
        final product = products[i];
        final stockStatus = product.isInStock ? '✅' : '❌';
        print(
          '  $stockStatus ${product.name} - ${product.price ?? 'No price'} - ${product.site}',
        );
      }

      if (inStockCount > 0) {
        print('\n✅ In-stock products:');
        final inStockProducts = products.where((p) => p.isInStock).take(5);
        for (final product in inStockProducts) {
          print('  ✅ ${product.name} - ${product.price ?? 'No price'}');
        }
      }

      print('\n🔗 Sample URLs:');
      for (int i = 0; i < products.length && i < 3; i++) {
        print('  ${products[i].url}');
      }
    } else {
      print('  ⚠️ No products found - there might still be an issue');
    }
  } catch (e) {
    print('💥 Error during crawl: $e');
  }
}
