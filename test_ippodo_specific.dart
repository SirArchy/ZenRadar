// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await testIppodoSpecific();
}

Future<void> testIppodoSpecific() async {
  print('=== Specific Ippodo Test ===');

  try {
    final response = await http.get(
      Uri.parse('https://global.ippodo-tea.co.jp/collections/matcha'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      },
    );

    if (response.statusCode != 200) {
      print('Failed to fetch page: ${response.statusCode}');
      return;
    }

    final document = html_parser.parse(response.body);
    print('Document parsed successfully\n');

    final productElements = document.querySelectorAll('.m-product-card');
    print('Found ${productElements.length} product elements\n');

    int validProducts = 0;
    final sampleProducts = <String>[];

    for (int i = 0; i < productElements.length && i < 3; i++) {
      final product = productElements[i];

      print('=== PRODUCT ${i + 1} ===');

      // Test name extraction - try multiple selectors
      String? productName;
      final nameSelectors = [
        '.m-product-card__name',
        '.m-product-card__body a',
      ];

      for (final selector in nameSelectors) {
        final nameElement = product.querySelector(selector);
        if (nameElement != null) {
          final name = nameElement.text.trim();
          if (name.isNotEmpty) {
            productName = name;
            print('Name ($selector): $productName');
            break;
          }
        }
      }

      if (productName == null) {
        print('Name: NOT FOUND');
        continue;
      }

      // Test price extraction
      final priceElement = product.querySelector('.m-product-card__price');
      final productPrice = priceElement?.text.trim() ?? '';
      print('Price: $productPrice');

      final hasName = productName.isNotEmpty;
      final hasPrice = productPrice.isNotEmpty && productPrice.contains('¥');

      print('Has name: $hasName');
      print('Has price: $hasPrice');
      print('Price contains ¥: ${productPrice.contains('¥')}');

      if (hasName && hasPrice) {
        validProducts++;
        sampleProducts.add('$productName - $productPrice');
        print('✅ VALID PRODUCT');
      } else {
        print('❌ INVALID PRODUCT');
      }
      print('');
    }

    print('=== RESULTS ===');
    print('Valid products: $validProducts');
    for (final sample in sampleProducts) {
      print('  • $sample');
    }

    if (validProducts > 0) {
      print('✅ Ippodo configuration is working!');
    } else {
      print('❌ Ippodo configuration needs fixing');
    }
  } catch (e) {
    print('Error: $e');
  }
}
