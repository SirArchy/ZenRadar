// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

Future<void> debugMatchaKaru() async {
  print('=== Debugging Matcha Kāru Structure ===');

  try {
    final client = http.Client();
    final response = await client
        .get(
          Uri.parse('https://matcha-karu.com/collections/matcha-tee'),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final document = parse.parse(response.body);
      final products = document.querySelectorAll('.product-item');

      print('Found ${products.length} products');

      if (products.isNotEmpty) {
        final firstProduct = products[0];
        print('\n=== First Product Full HTML ===');
        print(firstProduct.outerHtml);

        print('\n=== Testing Different Selectors ===');

        // Test different name selectors
        final nameSelectors = [
          'a[href*="/products/"]',
          '.product-item__info .product-item__title',
          '.product-item__title',
          'h3',
          '.product-title',
          'a',
          '.product-item__info h3',
          '.product-item__info a',
        ];

        for (String selector in nameSelectors) {
          final elements = firstProduct.querySelectorAll(selector);
          for (int i = 0; i < elements.length; i++) {
            final element = elements[i];
            final text = element.text.trim();
            final href = element.attributes['href'] ?? '';

            if (text.isNotEmpty || href.isNotEmpty) {
              print('Selector "$selector" [$i]: text="$text", href="$href"');
            }
          }
        }

        print('\n=== Testing Price Selectors ===');
        final priceSelectors = [
          '.price',
          '.price-list',
          '.product-item__price',
          '.money',
          '.price-item',
          '.price__current',
          '[class*="price"]',
          '[class*="money"]',
        ];

        for (String selector in priceSelectors) {
          final elements = firstProduct.querySelectorAll(selector);
          for (int i = 0; i < elements.length; i++) {
            final element = elements[i];
            final text = element.text.trim();
            if (text.isNotEmpty) {
              print('Price selector "$selector" [$i]: "$text"');
            }
          }
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
  await debugMatchaKaru();
}
