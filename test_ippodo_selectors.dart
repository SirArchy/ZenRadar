// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

Future<void> testIppodoSelectors() async {
  print('=== Testing Proposed Ippodo Selectors ===');

  try {
    final client = http.Client();
    final response = await client
        .get(
          Uri.parse('https://global.ippodo-tea.co.jp/collections/matcha'),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final document = parse.parse(response.body);

      // Test the proposed selectors
      final products = document.querySelectorAll('.m-product-card');
      print('Found ${products.length} products with .m-product-card');

      for (int i = 0; i < (products.length > 5 ? 5 : products.length); i++) {
        final product = products[i];
        print('\n=== Product ${i + 1} ===');

        // Test name extraction methods
        print('Name extraction attempts:');

        // Method 1: img alt attribute
        final imgEl = product.querySelector('img');
        if (imgEl != null) {
          final alt = imgEl.attributes['alt'] ?? '';
          print('  img alt: "$alt"');
        }

        // Method 2: link text in .m-product-card__body
        final bodyLinkEl = product.querySelector('.m-product-card__body a');
        if (bodyLinkEl != null) {
          print('  .m-product-card__body a text: "${bodyLinkEl.text.trim()}"');
        }

        // Method 3: any link with text
        final linkEls = product.querySelectorAll('a');
        for (int j = 0; j < linkEls.length; j++) {
          final link = linkEls[j];
          final text = link.text.trim();
          if (text.isNotEmpty) {
            print('  a[$j] text: "$text"');
          }
        }

        // Test price extraction
        final priceEl = product.querySelector('.m-product-card__price');
        if (priceEl != null) {
          print('Price: "${priceEl.text.trim()}"');
        }

        // Test link extraction
        final linkEl = product.querySelector('a[href*="/products/"]');
        if (linkEl != null) {
          print('Link: "${linkEl.attributes['href']}"');
        }

        // Test stock detection - look for common out-of-stock indicators
        final outOfStockIndicators = [
          '.sold-out',
          '.out-of-stock',
          '.unavailable',
          '[data-available="false"]',
        ];

        bool foundOutOfStock = false;
        for (String selector in outOfStockIndicators) {
          if (product.querySelector(selector) != null) {
            print('Out of stock indicator found: $selector');
            foundOutOfStock = true;
          }
        }

        if (!foundOutOfStock) {
          print('Stock status: Available (no out-of-stock indicators found)');
        }
      }
    } else {
      print('❌ HTTP ${response.statusCode}');
    }

    client.close();
  } catch (e) {
    print('💥 Error: $e');
  }
}

void main() async {
  await testIppodoSelectors();
}
