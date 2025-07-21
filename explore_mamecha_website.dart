// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await exploreMamechaWebsite();
}

Future<void> exploreMamechaWebsite() async {
  print('=== Exploring Mamecha Website Structure ===');

  try {
    // First check the main website
    print('=== Checking Main Website ===');
    var response = await http.get(
      Uri.parse('https://www.mamecha.com/'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      },
    );

    print('Main site status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final document = html_parser.parse(response.body);
      print(
        'Main page title: "${document.head?.querySelector('title')?.text ?? 'No title'}"',
      );

      // Look for any shop/product navigation links
      final shopLinks = document.querySelectorAll(
        'a[href*="shop"], a[href*="product"], a[href*="matcha"], a[href*="online"], a[href*="store"]',
      );
      print('\nFound ${shopLinks.length} potential shop links:');
      for (int i = 0; i < Math.min(10, shopLinks.length); i++) {
        final link = shopLinks[i];
        final href = link.attributes['href'];
        final text = link.text.trim();
        if (text.isNotEmpty && href != null) {
          print('  ${i + 1}. $href - "$text"');
        }
      }

      // Also look for any navigation menus
      final navLinks = document.querySelectorAll(
        'nav a, .nav a, .menu a, header a',
      );
      print('\nNavigation links found: ${navLinks.length}');
      for (int i = 0; i < Math.min(15, navLinks.length); i++) {
        final link = navLinks[i];
        final href = link.attributes['href'];
        final text = link.text.trim();
        if (text.isNotEmpty && href != null && href.contains('/')) {
          print('  ${i + 1}. $href - "$text"');
        }
      }
    }

    // Now check the configured base URL
    print('\n=== Checking Configured Base URL ===');
    response = await http.get(
      Uri.parse('https://www.mamecha.com/online-shopping-1/'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      },
    );

    print('Base URL status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final document = html_parser.parse(response.body);

      // Check for any actual product content
      final bodyText = document.body?.text ?? '';
      print(
        'Page contains "matcha": ${bodyText.toLowerCase().contains('matcha')}',
      );
      print('Page contains "tea": ${bodyText.toLowerCase().contains('tea')}');
      print('Page contains "shop": ${bodyText.toLowerCase().contains('shop')}');
      print('Page contains "buy": ${bodyText.toLowerCase().contains('buy')}');
      print('Page contains "€": ${bodyText.contains('€')}');

      // Look for any elements that might contain product info
      final textElements = document.querySelectorAll('p, div, span');
      int matchaProducts = 0;
      for (final element in textElements) {
        final text = element.text.toLowerCase();
        if (text.contains('matcha') &&
            (text.contains('€') ||
                text.contains('price') ||
                text.contains('buy'))) {
          matchaProducts++;
          if (matchaProducts <= 3) {
            print('Potential product text: "${element.text.trim()}"');
          }
        }
      }
      print('Found $matchaProducts potential product-related elements');
    }
  } catch (e) {
    print('Error: $e');
  }
}

class Math {
  static int min(int a, int b) => a < b ? a : b;
}
