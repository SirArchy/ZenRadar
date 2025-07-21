// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await debugIppodoAgain();
}

Future<void> debugIppodoAgain() async {
  print('=== Debugging Ippodo Tea Again ===');

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

    // Test current configuration
    final productSelector = '.m-product-card';

    final productElements = document.querySelectorAll(productSelector);
    print('Found ${productElements.length} product elements\n');

    for (int i = 0; i < productElements.length && i < 3; i++) {
      final product = productElements[i];

      print('=== PRODUCT ${i + 1} ===');
      print('Product HTML (first 500 chars):');
      print(
        product.outerHtml.length > 500
            ? '${product.outerHtml.substring(0, 500)}...'
            : product.outerHtml,
      );

      // Test name extraction
      print('\n--- NAME EXTRACTION ---');
      final nameSelectors = [
        '.m-product-card__body a',
        'img',
        '.m-product-card__title',
        '.m-product-card__name',
        'a',
        'h3',
        'h4',
        '.title',
      ];

      for (final selector in nameSelectors) {
        final elements = product.querySelectorAll(selector);
        for (int j = 0; j < elements.length; j++) {
          final element = elements[j];
          final text = element.text.trim();
          final alt = element.attributes['alt'];
          if (text.isNotEmpty || alt != null) {
            print('$selector[$j]: text="$text", alt="$alt"');
          }
        }
      }

      // Test price extraction
      print('\n--- PRICE EXTRACTION ---');
      final priceSelectors = [
        '.m-product-card__price',
        '.price',
        '.m-product-card__cost',
        '[class*="price"]',
        '.amount',
      ];

      for (final selector in priceSelectors) {
        final elements = product.querySelectorAll(selector);
        for (int j = 0; j < elements.length; j++) {
          final element = elements[j];
          final text = element.text.trim();
          if (text.isNotEmpty) {
            print('$selector[$j]: "$text"');
          }
        }
      }

      print('\n');
    }
  } catch (e) {
    print('Error: $e');
  }
}
