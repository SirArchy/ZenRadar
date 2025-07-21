// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await testMamechaConfig();
}

Future<void> testMamechaConfig() async {
  print('=== Testing Updated Mamecha Configuration ===');

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

    // Test the new configuration
    final productContainers = document.querySelectorAll('[id*="cc-m-product"]');
    print('✅ Found ${productContainers.length} product containers');

    int matchaProducts = 0;
    for (int i = 0; i < productContainers.length; i++) {
      final container = productContainers[i];

      // Test name selector
      final nameElement = container.querySelector('h4');
      final name = nameElement?.text.trim() ?? '';

      // Only process matcha-related products
      if (name.toLowerCase().contains('matcha') ||
          name.toLowerCase().contains('sencha') ||
          name.toLowerCase().contains('hojicha')) {
        matchaProducts++;
        print('\n--- Product $matchaProducts ---');
        print('Name: "$name"');

        // Test price selector
        final priceElements = container.querySelectorAll('span, div');
        String? price;
        for (final priceElement in priceElements) {
          final priceText = priceElement.text.trim();
          if (priceText.contains('€') &&
              priceText.length < 30 &&
              !priceText.contains('0,00')) {
            price = priceText;
            break;
          }
        }
        if (price != null) {
          print('Price: "$price"');
        } else {
          print('Price: Not found');
        }

        // Test link selector
        final linkElement = container.querySelector('a[href*="/j/shop/"]');
        final link = linkElement?.attributes['href'];
        if (link != null) {
          print('Link: "$link"');
        } else {
          print('Link: Not found');
        }

        // Test stock determination
        final elementText = container.text.toLowerCase();
        final isInStock =
            elementText.contains('verfügbar') &&
            !elementText.contains('ausverkauft') &&
            !elementText.contains('leider ausverkauft');
        print('Stock: ${isInStock ? '✅ Available' : '❌ Out of stock'}');

        if (matchaProducts >= 5) break; // Limit to first 5 matcha products
      }
    }

    print('\n=== Summary ===');
    print('Total matcha/tea products found: $matchaProducts');
  } catch (e) {
    print('Error: $e');
  }
}
