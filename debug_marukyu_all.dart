// Check all Marukyu products for any in-stock items
// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

void main() async {
  print('🔍 Checking ALL Marukyu products for stock status...');

  const url =
      'https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha?currency=USD';

  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );

    if (response.statusCode == 200) {
      final document = parse(response.body);

      final productElements = document.querySelectorAll('.products .product');
      print('📦 Found ${productElements.length} total products');

      int inStockCount = 0;
      int outOfStockCount = 0;
      List<String> inStockProducts = [];
      Set<String> allClasses = {};

      for (int i = 0; i < productElements.length; i++) {
        final product = productElements[i];
        final name =
            product.querySelector('.product-name')?.text.trim() ?? 'Unknown $i';

        // Collect all classes to see what's available
        allClasses.addAll(product.classes);

        final hasOutOfStockClass = product.classes.contains('outofstock');
        final hasInStockClass = product.classes.contains('instock');

        bool isInStock =
            !hasOutOfStockClass &&
            (hasInStockClass || !product.classes.contains('outofstock'));

        if (isInStock) {
          inStockCount++;
          inStockProducts.add(name);
          print('✅ IN STOCK: "$name" (classes: ${product.classes.join(', ')})');
        } else {
          outOfStockCount++;
        }
      }

      print('\n📊 Final Results:');
      print('  ✅ In Stock: $inStockCount');
      print('  ❌ Out of Stock: $outOfStockCount');
      print('  📦 Total products: ${productElements.length}');

      if (inStockProducts.isNotEmpty) {
        print('\n✅ In-stock products:');
        for (String productName in inStockProducts) {
          print('  - $productName');
        }
      }

      print('\n🏷️ All classes found across products:');
      final sortedClasses = allClasses.toList()..sort();
      for (String className in sortedClasses) {
        print('  - $className');
      }

      // Test the actual crawler logic with current config
      print('\n🧪 Testing current crawler configuration:');

      // Simulate the parsing with current selectors
      const productSelector = '.item, .product-item, .product';
      const nameSelector = '.item-name, .product-name, .name, h3';
      const priceSelector = '.price, .item-price, .cost';
      const linkSelector = 'a, .item-link';

      final selectedProducts = document.querySelectorAll(productSelector);
      print(
        '  Product selector "$productSelector": ${selectedProducts.length} elements',
      );

      int validProducts = 0;
      for (final product in selectedProducts.take(5)) {
        final nameElement = product.querySelector(nameSelector);
        final priceElement = product.querySelector(priceSelector);
        product.querySelector(linkSelector);

        if (nameElement != null) {
          final name = nameElement.text.trim();
          final price = priceElement?.text.trim() ?? 'No price';
          final isInStock = !product.classes.contains('outofstock');

          print(
            '  ✅ Valid product: "$name" - $price - Stock: ${isInStock ? "✅" : "❌"}',
          );
          validProducts++;
        }
      }

      print('  📊 Valid products found: $validProducts');
    } else {
      print('❌ Failed to fetch page: ${response.statusCode}');
    }
  } catch (e) {
    print('💥 Error: $e');
  }
}
