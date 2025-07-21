// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

Future<void> debugYoshiEn() async {
  print('=== Debugging Yoshi En Structure ===');

  try {
    final client = http.Client();
    final response = await client
        .get(
          Uri.parse('https://www.yoshien.com/matcha/'),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final document = parse.parse(response.body);

      print(
        'Page title: ${document.querySelector('title')?.text ?? 'No title'}',
      );
      print('Response length: ${response.body.length} characters');

      // Test current selectors
      print('\n=== Testing Current Selectors ===');
      final currentSelectors = ['table tbody tr', 'table tr', 'table'];

      for (String selector in currentSelectors) {
        final elements = document.querySelectorAll(selector);
        print(
          'Current selector "$selector": ${elements.length} elements found',
        );

        if (elements.isNotEmpty && elements.length < 20) {
          for (
            int i = 0;
            i < (elements.length > 3 ? 3 : elements.length);
            i++
          ) {
            final element = elements[i];
            final text = element.text.trim();
            final shortText =
                text.length > 100 ? '${text.substring(0, 100)}...' : text;
            print('  Element ${i + 1}: "$shortText"');

            // Check if it contains matcha links
            final matchaLinks = element.querySelectorAll('a[href*="matcha"]');
            print('    Matcha links found: ${matchaLinks.length}');
          }
        }
      }

      // Look for product-related patterns
      print('\n=== Looking for Product Patterns ===');
      final productSelectors = [
        '.product',
        '.item',
        '.card',
        '.list-item',
        '.product-item',
        '[class*="product"]',
        '[class*="item"]',
        'article',
        '.entry',
        '.post',
      ];

      for (String selector in productSelectors) {
        final elements = document.querySelectorAll(selector);
        if (elements.isNotEmpty && elements.length < 50) {
          print(
            'Product selector "$selector": ${elements.length} elements found',
          );

          if (elements.isNotEmpty) {
            final firstElement = elements[0];
            final text = firstElement.text.trim();
            final shortText =
                text.length > 150 ? '${text.substring(0, 150)}...' : text;
            print('  Sample: "$shortText"');

            // Check for matcha-related content
            if (text.toLowerCase().contains('matcha')) {
              print('  ✅ Contains matcha content');

              // Look for links
              final links = firstElement.querySelectorAll('a');
              for (int i = 0; i < links.length; i++) {
                final link = links[i];
                final href = link.attributes['href'] ?? '';
                final linkText = link.text.trim();
                if (href.isNotEmpty || linkText.isNotEmpty) {
                  print('    Link $i: href="$href", text="$linkText"');
                }
              }

              // Look for prices
              final pricePattern = RegExp(r'([\d,]+[.,]\d+)\s*[€$£¥]?');
              final priceMatches = pricePattern.allMatches(text);
              for (var match in priceMatches) {
                print('    Potential price: "${match.group(0)}"');
              }
            }
          }
        }
      }

      // Look for any links containing "matcha"
      print('\n=== All Matcha Links ===');
      final matchaLinks = document.querySelectorAll('a[href*="matcha"]');
      print('Found ${matchaLinks.length} links containing "matcha"');

      for (
        int i = 0;
        i < (matchaLinks.length > 10 ? 10 : matchaLinks.length);
        i++
      ) {
        final link = matchaLinks[i];
        final href = link.attributes['href'] ?? '';
        final text = link.text.trim();
        print('Link ${i + 1}: href="$href", text="$text"');
      }

      // Check overall page structure
      print('\n=== Page Structure Analysis ===');
      final mainContent = document.querySelector(
        'main, .main, .content, #content, .container',
      );
      if (mainContent != null) {
        print(
          'Main content area found: ${mainContent.localName}.${mainContent.attributes['class'] ?? ''}',
        );
        final productElements =
            mainContent
                .querySelectorAll('*')
                .where((el) {
                  final text = el.text.toLowerCase();
                  return text.contains('matcha') &&
                      text.length > 10 &&
                      text.length < 500;
                })
                .take(5)
                .toList();

        print(
          'Product-like elements in main content: ${productElements.length}',
        );
        for (int i = 0; i < productElements.length; i++) {
          final el = productElements[i];
          final text = el.text.trim();
          final shortText =
              text.length > 200 ? '${text.substring(0, 200)}...' : text;
          print('  Element ${i + 1} (${el.localName}): "$shortText"');
        }
      }
    } else {
      print('❌ HTTP ${response.statusCode}');
      print('Response headers: ${response.headers}');
    }

    client.close();
  } catch (e) {
    print('💥 Error: $e');
  }
}

void main() async {
  await debugYoshiEn();
}
