// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

Future<void> debugIppodo() async {
  print('=== Debugging Ippodo Tea Structure ===');

  try {
    final client = http.Client();
    final response = await client
        .get(
          Uri.parse('https://global.ippodo-tea.co.jp/collections/matcha'),
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
      final currentSelectors = [
        '.grid__item',
        '.product-item',
        '.card-wrapper',
      ];

      for (String selector in currentSelectors) {
        final elements = document.querySelectorAll(selector);
        print(
          'Current selector "$selector": ${elements.length} elements found',
        );

        if (elements.isNotEmpty) {
          final firstElement = elements[0];
          print('  First element classes: ${firstElement.attributes['class']}');
          print(
            '  First element HTML (first 200 chars): ${firstElement.outerHtml.substring(0, firstElement.outerHtml.length > 200 ? 200 : firstElement.outerHtml.length)}...',
          );
        }
      }

      // Look for common Shopify patterns
      final shopifySelectors = [
        '.product-card',
        '.card',
        '.product',
        '.collection-item',
        '.grid-item',
        '.product-list-item',
        '[data-product-id]',
        '.product-block',
        '.product-tile',
      ];

      print('\n=== Testing Common Shopify Patterns ===');
      for (String selector in shopifySelectors) {
        final elements = document.querySelectorAll(selector);
        if (elements.isNotEmpty) {
          print(
            'Shopify selector "$selector": ${elements.length} elements found',
          );

          if (elements.isNotEmpty && elements.length < 50) {
            final firstElement = elements[0];

            // Try to find name in this element
            final nameSelectors = [
              '.card__heading a',
              '.card__heading',
              'h3 a',
              'h3',
              '.product-title',
              '.product-name',
              'a[href*="/products/"]',
            ];

            for (String nameSelector in nameSelectors) {
              final nameEl = firstElement.querySelector(nameSelector);
              if (nameEl != null && nameEl.text.trim().isNotEmpty) {
                print(
                  '  Name found with "$nameSelector": "${nameEl.text.trim()}"',
                );
                break;
              }
            }

            // Try to find price
            final priceSelectors = [
              '.price__current .price-item--regular',
              '.price .price-item',
              '.price',
              '.cost',
              '.money',
              '[class*="price"]',
            ];

            for (String priceSelector in priceSelectors) {
              final priceEl = firstElement.querySelector(priceSelector);
              if (priceEl != null && priceEl.text.trim().isNotEmpty) {
                print(
                  '  Price found with "$priceSelector": "${priceEl.text.trim()}"',
                );
                break;
              }
            }
          }
        }
      }

      // Look for any elements that might contain matcha products
      print('\n=== Looking for matcha-related content ===');
      final matchaElements =
          document
              .querySelectorAll('*')
              .where((element) {
                final text = element.text.toLowerCase();
                final classes = element.attributes['class'] ?? '';
                return text.contains('matcha') ||
                    classes.contains('product') ||
                    classes.contains('item');
              })
              .take(10)
              .toList();

      for (int i = 0; i < matchaElements.length; i++) {
        final element = matchaElements[i];
        print(
          'Matcha element ${i + 1}: tag="${element.localName}", classes="${element.attributes['class']}", text="${element.text.trim().substring(0, element.text.trim().length > 50 ? 50 : element.text.trim().length)}"',
        );
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
  await debugIppodo();
}
