// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await testAllSites();
}

Future<void> testAllSites() async {
  print('=== Testing All Site Configurations ===\n');

  final siteConfigs = {
    'matcha-karu': {
      'url': 'https://matchakaru.de/pages/alle-matcha-sorten',
      'productSelector': '.product-item',
      'nameSelector': '.product-item-meta__title',
      'priceSelector': '.price',
    },
    'ippodo-tea': {
      'url':
          'https://ippodotea.com/collections/matcha-japanese-green-tea-powder',
      'productSelector': '.product-item',
      'nameSelector': '.product-item__info .product-item__title a',
      'priceSelector': '.price',
    },
    'yoshi-en': {
      'url':
          'https://www.yoshi-en.com/collections/matcha?sort_by=title-ascending',
      'productSelector': '.product-item',
      'nameSelector': '.product-form__cart .product-title',
      'priceSelector': '.price--highlight, .price',
    },
    'sazen-tea': {
      'url': 'https://www.sazentea.com/en/products/c21-matcha',
      'productSelector': '.product-item',
      'nameSelector': '.item-title a',
      'priceSelector': '.item-price .product-price',
    },
    'sho-cha': {
      'url': 'https://www.sho-cha.com/teeshop',
      'productSelector': '.ProductList-item',
      'nameSelector': '.ProductList-title',
      'priceSelector': '.product-price',
    },
  };

  for (final siteEntry in siteConfigs.entries) {
    final siteName = siteEntry.key;
    final config = siteEntry.value;

    print('Testing $siteName...');

    try {
      final response = await http.get(
        Uri.parse(config['url']!),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
        },
      );

      if (response.statusCode != 200) {
        print('❌ $siteName: Failed to fetch (${response.statusCode})\n');
        continue;
      }

      final document = html_parser.parse(response.body);
      final products = document.querySelectorAll(config['productSelector']!);

      if (products.isEmpty) {
        print(
          '❌ $siteName: No products found with selector "${config['productSelector']}"\n',
        );
        continue;
      }

      int validProducts = 0;
      for (int i = 0; i < Math.min(3, products.length); i++) {
        final product = products[i];

        final nameElement = product.querySelector(config['nameSelector']!);
        final priceElement = product.querySelector(config['priceSelector']!);

        final name = nameElement?.text.trim() ?? '';
        final price = priceElement?.text.trim() ?? '';

        if (name.isNotEmpty && price.isNotEmpty) {
          validProducts++;
        }
      }

      if (validProducts > 0) {
        print(
          '✅ $siteName: ${products.length} products found, $validProducts/${Math.min(3, products.length)} valid samples',
        );
      } else {
        print(
          '❌ $siteName: ${products.length} products found, but no valid data extracted',
        );
      }
    } catch (e) {
      print('❌ $siteName: Error - $e');
    }

    print('');
  }

  print('=== Test Complete ===');
}

class Math {
  static int min(int a, int b) => a < b ? a : b;
}
