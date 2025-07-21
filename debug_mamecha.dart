// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await debugMamechaStructure();
}

Future<void> debugMamechaStructure() async {
  print('=== Debugging Mamecha Website Structure ===');

  try {
    final response = await http.get(
      Uri.parse('https://www.mamecha.com/online-shopping-1/'),
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
    print(
      'Page title: "${document.head?.querySelector('title')?.text ?? 'No title'}"',
    );
    print('Page URL: ${response.request?.url}');

    // Check current configured selectors
    final currentSelectors = [
      '.summary-item',
      '.ProductList-item',
      '.summary-title',
      '.ProductList-title',
      '.summary-metadata',
      '.ProductList-price',
    ];

    for (final selector in currentSelectors) {
      final elements = document.querySelectorAll(selector);
      print('Selector "$selector": ${elements.length} found');
    }

    // Check for common e-commerce patterns
    final commonSelectors = [
      '.product',
      '.product-item',
      '.product-card',
      '.item',
      '[class*="product"]',
      '.grid-item',
      '.collection-item',
      '.summary-item',
      '.ProductList-item',
      '.sqs-gallery-block-grid',
      '.sqs-block-product',
      '.ProductList',
      '.summary-v2',
    ];

    print('\n=== Testing Common E-commerce Selectors ===');
    for (final selector in commonSelectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        print('✅ Selector "$selector": ${elements.length} found');

        if (elements.isNotEmpty && elements.length < 50) {
          final firstElement = elements.first;
          print('   First element classes: ${firstElement.classes.join(', ')}');

          // Look for matcha-related content
          if (firstElement.text.toLowerCase().contains('matcha')) {
            print('   Contains matcha content!');
            print(
              '   Text sample: "${firstElement.text.trim().substring(0, Math.min(100, firstElement.text.trim().length))}..."',
            );
          }
        }
      }
    }

    // Look for any matcha links
    final matchaLinks = document.querySelectorAll(
      'a[href*="matcha"], a[href*="product"]',
    );
    print('\n=== Matcha/Product Links Found ===');
    print('Found ${matchaLinks.length} matcha/product links');
    for (int i = 0; i < Math.min(5, matchaLinks.length); i++) {
      final link = matchaLinks[i];
      print(
        'Link ${i + 1}: ${link.attributes['href']} - "${link.text.trim()}"',
      );
    }

    // Check page content for any form of product listings
    final pageText = document.body?.text ?? '';
    final hasMatcha = pageText.toLowerCase().contains('matcha');
    final hasProduct = pageText.toLowerCase().contains('product');
    final hasShop = pageText.toLowerCase().contains('shop');

    print('\n=== Page Content Analysis ===');
    print('Contains "matcha": $hasMatcha');
    print('Contains "product": $hasProduct');
    print('Contains "shop": $hasShop');
    print('Page length: ${pageText.length} characters');
  } catch (e) {
    print('Error: $e');
  }
}

class Math {
  static int min(int a, int b) => a < b ? a : b;
}
