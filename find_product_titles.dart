// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await findProductTitles();
}

Future<void> findProductTitles() async {
  print('=== Finding Product Titles in Yoshi En ===');

  try {
    final response = await http.get(
      Uri.parse('https://www.yoshien.com/matcha/matcha-tee/'),
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
    final products = document.querySelectorAll('.cs-product-tile');

    print('Found ${products.length} products');

    int realProducts = 0;
    for (int i = 0; i < products.length && realProducts < 3; i++) {
      final product = products[i];

      // Skip template products
      if (product.classes.contains('article-template') ||
          product.classes.contains('product-template') ||
          product.attributes['style']?.contains('display: none') == true) {
        continue;
      }

      realProducts++;
      print('\n=== Product $realProducts ===');

      // Look for all possible text elements
      final allElements = product.querySelectorAll('*');
      for (final element in allElements) {
        final text = element.text.trim();
        if (text.isNotEmpty &&
            text.length < 200 &&
            !text.startsWith('<') &&
            !text.contains('€') &&
            (text.toLowerCase().contains('matcha') ||
                text.toLowerCase().contains('bio'))) {
          print(
            'Text in "${element.localName}.${element.classes.join('.')}" (${element.attributes.keys.join(', ')}): "$text"',
          );
        }
      }

      // Look specifically for img alt attributes
      final images = product.querySelectorAll('img[alt]');
      for (final img in images) {
        final alt = img.attributes['alt'];
        if (alt != null &&
            alt.isNotEmpty &&
            alt.toLowerCase().contains('matcha')) {
          print('✅ IMG ALT: "$alt"');
        }
      }

      // Look for strong/span/a text that could be product names
      final textElements = product.querySelectorAll(
        'strong, span, a, h3, h4, .title, [class*="title"], [class*="name"]',
      );
      for (final element in textElements) {
        final text = element.text.trim();
        if (text.isNotEmpty &&
            text.length < 100 &&
            text.toLowerCase().contains('matcha') &&
            !text.contains('<img')) {
          print(
            '✅ TEXT ELEMENT "${element.localName}.${element.classes.join('.')}" (${element.attributes.keys.join(', ')}): "$text"',
          );
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
