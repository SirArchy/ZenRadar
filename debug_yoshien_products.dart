// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

Future<void> debugYoshiEnProducts() async {
  print('=== Debugging Yoshi En Product Structure ===');

  try {
    final client = http.Client();
    final response = await client
        .get(
          Uri.parse('https://www.yoshien.com/matcha/'),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final document = parse.parse(response.body);

      // Focus on .item elements since we found 18 of them
      final items = document.querySelectorAll('.item');
      print('Found ${items.length} .item elements');

      for (int i = 0; i < (items.length > 5 ? 5 : items.length); i++) {
        final item = items[i];
        print('\n=== Item ${i + 1} ===');
        print('Classes: ${item.attributes['class']}');
        print('HTML (first 300 chars):');
        print(
          '${item.outerHtml.substring(0, item.outerHtml.length > 300 ? 300 : item.outerHtml.length)}...',
        );

        // Check for product information
        final text = item.text.trim();
        print(
          'Text content: "${text.length > 100 ? '${text.substring(0, 100)}...' : text}"',
        );

        // Look for links
        final links = item.querySelectorAll('a');
        print('Links found: ${links.length}');
        for (int j = 0; j < links.length; j++) {
          final link = links[j];
          final href = link.attributes['href'] ?? '';
          final linkText = link.text.trim();
          if (href.isNotEmpty || linkText.isNotEmpty) {
            print('  Link ${j + 1}: href="$href", text="$linkText"');
          }
        }

        // Look for prices
        final pricePattern = RegExp(r'(\d+[.,]\d+)\s*€?');
        final priceMatches = pricePattern.allMatches(text);
        for (var match in priceMatches) {
          print('  Potential price: "${match.group(0)}"');
        }

        // Check if this looks like a product
        final isProductLike =
            text.toLowerCase().contains('matcha') &&
            links.isNotEmpty &&
            (priceMatches.isNotEmpty || text.contains('€'));
        print('  Looks like product: $isProductLike');
      }

      // Also check if there's a different product listing structure
      print('\n=== Alternative Product Structures ===');

      // Look for product listing containers
      final productContainers = [
        '.products',
        '.product-list',
        '.grid',
        '.list',
        '.category-products',
        '[class*="product"]',
        '[class*="grid"]',
        '.cs-product',
        '.cs-item',
      ];

      for (String selector in productContainers) {
        final containers = document.querySelectorAll(selector);
        if (containers.isNotEmpty) {
          print('Container "$selector": ${containers.length} found');

          final container = containers[0];
          final items = container.querySelectorAll(
            '.item, .product, .entry, article, div',
          );
          print('  Contains ${items.length} child elements');

          // Check first few child elements for product-like content
          for (int i = 0; i < (items.length > 3 ? 3 : items.length); i++) {
            final item = items[i];
            final text = item.text.trim();
            if (text.toLowerCase().contains('matcha') && text.length > 20) {
              print(
                '  Child ${i + 1}: "${text.length > 80 ? '${text.substring(0, 80)}...' : text}"',
              );

              final links = item.querySelectorAll('a');
              for (var link in links) {
                final href = link.attributes['href'] ?? '';
                final linkText = link.text.trim();
                if (href.contains('matcha') ||
                    linkText.toLowerCase().contains('matcha')) {
                  print('    Matcha link: href="$href", text="$linkText"');
                }
              }
            }
          }
        }
      }

      // Try to find the actual matcha tea products page
      print('\n=== Checking Matcha Tea Page ===');
      final matchaTeaLink = document.querySelector('a[href*="matcha-tee"]');
      if (matchaTeaLink != null) {
        final href = matchaTeaLink.attributes['href'];
        print('Found matcha tea page link: $href');
      }
    } else {
      print('❌ HTTP ${response.statusCode}');
    }

    client.close();
  } catch (e) {
    print('💥 Error: $e');
  }
}

void main() async {
  await debugYoshiEnProducts();
}
