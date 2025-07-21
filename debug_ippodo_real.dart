// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

Future<void> debugIppodoRealProducts() async {
  print('=== Finding Real Ippodo Product Structure ===');

  try {
    final client = http.Client();
    final response = await client
        .get(
          Uri.parse('https://global.ippodo-tea.co.jp/collections/matcha'),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final document = parse.parse(response.body);

      // Get wishlist buttons and find their parent product containers
      final wishlistButtons = document.querySelectorAll('[data-product-id]');
      print('Found ${wishlistButtons.length} wishlist buttons');

      if (wishlistButtons.isNotEmpty) {
        for (
          int i = 0;
          i < (wishlistButtons.length > 3 ? 3 : wishlistButtons.length);
          i++
        ) {
          final button = wishlistButtons[i];
          print('\n=== Analyzing Product ${i + 1} Container ===');

          // Look for parent elements that might be the product container
          var currentElement = button.parent;
          var level = 1;

          while (currentElement != null && level <= 5) {
            final classes = currentElement.attributes['class'] ?? '';
            final tagName = currentElement.localName;

            print('Level $level: <$tagName> classes="$classes"');

            // Check if this level has product information
            final nameEl = currentElement.querySelector(
              'h3, .product-title, .card-title, a[href*="/products/"]',
            );
            final priceEl = currentElement.querySelector(
              '.price, .money, [class*="price"]',
            );

            if (nameEl != null && nameEl.text.trim().isNotEmpty) {
              print('  ✅ Name found: "${nameEl.text.trim()}"');
              print(
                '  Name selector used: ${nameEl.localName}.${nameEl.attributes['class'] ?? ''}',
              );
            }

            if (priceEl != null && priceEl.text.trim().isNotEmpty) {
              print('  ✅ Price found: "${priceEl.text.trim()}"');
              print(
                '  Price selector used: ${priceEl.localName}.${priceEl.attributes['class'] ?? ''}',
              );
            }

            // If we found both name and price, this is likely the product container
            if (nameEl != null && priceEl != null) {
              print('  🎯 This looks like the product container!');
              print('  Container classes: "$classes"');

              // Show some of the HTML structure
              final htmlSample = currentElement.outerHtml.substring(
                0,
                currentElement.outerHtml.length > 800
                    ? 800
                    : currentElement.outerHtml.length,
              );
              print('  HTML sample:\n$htmlSample...');
              break;
            }

            currentElement = currentElement.parent;
            level++;
          }
        }
      }

      // Also try to find product containers by looking for elements that contain both product links and prices
      print('\n=== Alternative: Looking for elements with product links ===');
      final productLinks = document.querySelectorAll('a[href*="/products/"]');
      print('Found ${productLinks.length} product links');

      for (
        int i = 0;
        i < (productLinks.length > 3 ? 3 : productLinks.length);
        i++
      ) {
        final link = productLinks[i];
        final href = link.attributes['href'] ?? '';
        final text = link.text.trim();

        print('\nProduct link ${i + 1}: "$text" -> $href');

        // Find the container that has both this link and a price
        var container = link.parent;
        var level = 1;

        while (container != null && level <= 5) {
          final priceEl = container.querySelector(
            '.price, .money, [class*="price"]',
          );
          if (priceEl != null && priceEl.text.trim().isNotEmpty) {
            print(
              '  Found price in level $level container: "${priceEl.text.trim()}"',
            );
            print(
              '  Container classes: "${container.attributes['class'] ?? ''}"',
            );
            break;
          }
          container = container.parent;
          level++;
        }
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
  await debugIppodoRealProducts();
}
