// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await checkMamechaProductPage();
}

Future<void> checkMamechaProductPage() async {
  print('=== Checking Individual Mamecha Product Page ===');

  // Let's try one of the demo URLs from the config
  final productUrl = 'https://www.mamecha.com/products/traditional-matcha';

  try {
    final response = await http.get(
      Uri.parse(productUrl),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      },
    );

    print('Status: ${response.statusCode}');
    print('URL: ${response.request?.url}');

    if (response.statusCode != 200) {
      print('Failed to fetch product page: ${response.statusCode}');

      // Try to check if the main shop URL exists or redirects
      print('\n=== Checking Main Shop Page ===');
      final shopResponse = await http.get(
        Uri.parse('https://www.mamecha.com/shop/'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
        },
      );

      print('Shop page status: ${shopResponse.statusCode}');
      print('Shop page URL: ${shopResponse.request?.url}');

      if (shopResponse.statusCode == 200) {
        final document = html_parser.parse(shopResponse.body);
        print(
          'Shop page title: "${document.head?.querySelector('title')?.text ?? 'No title'}"',
        );

        // Look for product links
        final productLinks = document.querySelectorAll(
          'a[href*="product"], a[href*="matcha"]',
        );
        print('Found ${productLinks.length} product/matcha links');
        for (int i = 0; i < Math.min(10, productLinks.length); i++) {
          final link = productLinks[i];
          final href = link.attributes['href'];
          final text = link.text.trim();
          if (text.isNotEmpty && text.length < 100) {
            print('  Link ${i + 1}: $href - "$text"');
          }
        }
      }
      return;
    }

    final document = html_parser.parse(response.body);
    print(
      'Product page title: "${document.head?.querySelector('title')?.text ?? 'No title'}"',
    );

    // Check if this is a valid product page
    final bodyText = document.body?.text ?? '';
    print('Contains "matcha": ${bodyText.toLowerCase().contains('matcha')}');
    print('Contains "price": ${bodyText.toLowerCase().contains('price')}');
    print('Contains "€": ${bodyText.contains('€')}');
    print('Page content length: ${bodyText.length} characters');
  } catch (e) {
    print('Error: $e');
  }
}

class Math {
  static int min(int a, int b) => a < b ? a : b;
}
