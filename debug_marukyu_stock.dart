// Test stock status on Marukyu website
// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

void main() async {
  print('🔍 Testing Marukyu stock status logic...');

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
      print('📦 Found ${productElements.length} products to analyze');

      int inStockCount = 0;
      int outOfStockCount = 0;

      for (int i = 0; i < productElements.length; i++) {
        final product = productElements[i];
        final name =
            product.querySelector('.product-name')?.text.trim() ?? 'Unknown';
        final hasOutOfStockClass = product.classes.contains('outofstock');
        final hasInStockClass = product.classes.contains('instock');
        final allClasses = product.classes.toList();

        // Check various stock indicators
        final addToCartButton = product.querySelector(
          '.add-to-cart, button[type="submit"], .cart-form button',
        );
        final isButtonDisabled =
            addToCartButton?.attributes['disabled'] != null;

        // Also check for stock text
        final stockText = product.text.toLowerCase();
        final hasOutOfStockText =
            stockText.contains('out of stock') ||
            stockText.contains('sold out');
        final hasInStockText =
            stockText.contains('in stock') || stockText.contains('available');

        print('\n📦 Product ${i + 1}: "$name"');
        print('  Classes: ${allClasses.join(', ')}');
        print('  Has outofstock class: $hasOutOfStockClass');
        print('  Has instock class: $hasInStockClass');
        print('  Button disabled: $isButtonDisabled');
        print('  Out of stock text: $hasOutOfStockText');
        print('  In stock text: $hasInStockText');

        // Determine stock status
        bool isInStock;
        if (hasInStockClass) {
          isInStock = true;
        } else if (hasOutOfStockClass) {
          isInStock = false;
        } else {
          // Fallback logic
          isInStock = !isButtonDisabled && !hasOutOfStockText;
        }

        print(
          '  Final stock status: ${isInStock ? "✅ IN STOCK" : "❌ OUT OF STOCK"}',
        );

        if (isInStock) {
          inStockCount++;
        } else {
          outOfStockCount++;
        }

        // Show only first 5 for brevity
        if (i >= 4) break;
      }

      print('\n📊 Stock Summary:');
      print('  ✅ In Stock: $inStockCount');
      print('  ❌ Out of Stock: $outOfStockCount');
      print('  📦 Total analyzed: ${inStockCount + outOfStockCount}');

      // Check if all products really are out of stock (seems unlikely)
      if (outOfStockCount > 0 && inStockCount == 0) {
        print('\n⚠️ Warning: All products appear to be out of stock.');
        print(
          '   This might indicate the stock detection logic needs adjustment.',
        );
      }
    } else {
      print('❌ Failed to fetch page: ${response.statusCode}');
    }
  } catch (e) {
    print('💥 Error: $e');
  }
}
