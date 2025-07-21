// Test the complete Poppatea integration
// ignore_for_file: avoid_print

import 'lib/services/crawler_service.dart';

void main() async {
  print('🧪 Testing complete Poppatea integration...');

  try {
    final crawler = CrawlerService.instance;

    print('📡 Starting crawl of Poppatea...');
    final products = await crawler.crawlSite('poppatea');

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
          '  $stockStatus ${product.name} - ${product.price ?? 'No price'} (${product.priceValue ?? 'No value'}) - ${product.site}',
        );
      }

      if (inStockCount > 0) {
        print('\n✅ In-stock products with prices:');
        final inStockProducts = products
            .where((p) => p.isInStock && p.price != null)
            .take(3);
        for (final product in inStockProducts) {
          print(
            '  ✅ ${product.name} - ${product.price} (value: ${product.priceValue})',
          );
        }
      }

      // Test price value calculation
      final productsWithPrices =
          products.where((p) => p.price != null).toList();
      final productsWithPriceValues =
          products.where((p) => p.priceValue != null).toList();

      print('\n💰 Price analysis:');
      print('  Products with price strings: ${productsWithPrices.length}');
      print('  Products with price values: ${productsWithPriceValues.length}');

      if (productsWithPrices.length == productsWithPriceValues.length) {
        print('  ✅ All products with prices have calculated price values!');
      } else {
        print('  ⚠️ Some products missing price values');
      }

      print('\n🔗 Sample URLs:');
      for (int i = 0; i < products.length && i < 3; i++) {
        print('  ${products[i].url}');
      }
    } else {
      print(
        '  ⚠️ No products found - there might be an issue with the integration',
      );
    }
  } catch (e) {
    print('💥 Error during crawl: $e');
  }
}
