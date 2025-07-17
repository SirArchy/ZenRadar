// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

Future<void> debugMatcharuNames() async {
  print('=== Debugging Matcha Kāru Name Extraction ===');

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
        print('\nFirst product HTML structure:');
        print('${firstProduct.outerHtml.substring(0, 500)}...');

        // Try different name selectors
        final nameSelectors = [
          '.product-title',
          'h3',
          '.card-title',
          'a[href*="/products/"]',
          '.product-item__title',
          '.h4',
          'h4',
          '.product-form__cart-submit[data-product-title]',
        ];

        for (String selector in nameSelectors) {
          final nameEl = firstProduct.querySelector(selector);
          if (nameEl != null) {
            if (selector.contains('data-product-title')) {
              print(
                'Found name in $selector attribute: "${nameEl.attributes['data-product-title']}"',
              );
            } else {
              print('Found name with $selector: "${nameEl.text.trim()}"');
            }
          }
        }
      }
    }

    client.close();
  } catch (e) {
    print('Error: $e');
  }
}

Future<void> debugShochaPrices() async {
  print('\n=== Debugging Sho-Cha Price Extraction ===');

  try {
    final client = http.Client();
    final response = await client
        .get(
          Uri.parse('https://www.sho-cha.com/teeshop'),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final document = parse.parse(response.body);
      final products = document.querySelectorAll('.ProductList-item');

      print('Found ${products.length} products');

      if (products.isNotEmpty) {
        final firstProduct = products[0];
        print('\nFirst product structure around price:');

        // Look for any price-related elements
        final priceSelectors = [
          '.ProductList-price',
          '.sqs-money-native',
          '.price',
          '[class*="price"]',
          '[class*="money"]',
        ];

        for (String selector in priceSelectors) {
          final priceEl = firstProduct.querySelector(selector);
          if (priceEl != null) {
            print('Found with $selector: "${priceEl.text.trim()}"');
          }
        }

        // Also check the full HTML of the product
        print('\nFull product HTML (first 800 chars):');
        print('${firstProduct.outerHtml.substring(0, 800)}...');
      }
    }

    client.close();
  } catch (e) {
    print('Error: $e');
  }
}

void main() async {
  await debugMatcharuNames();
  await debugShochaPrices();
}
