// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  print('🔍 Finding correct Poppatea product structure...\n');

  try {
    final response = await http.get(
      Uri.parse('https://poppatea.com/de-de/collections/all-teas'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept-Language': 'de-DE,de;q=0.9,en;q=0.8',
      },
    );

    if (response.statusCode == 200) {
      final document = parser.parse(response.body);

      // Get all product links first
      final productLinks = document.querySelectorAll('a[href*="/products/"]');
      print('📝 Found ${productLinks.length} product links');

      for (int i = 0; i < productLinks.length && i < 5; i++) {
        final link = productLinks[i];
        print('\n--- Product Link ${i + 1} ---');
        print('🔗 Href: ${link.attributes['href']}');
        print('📝 Text: "${link.text.trim()}"');
        print('🏷️ Classes: ${link.classes}');

        // Walk up the DOM tree to find the product container
        var current = link.parent;
        int level = 1;
        while (current != null && level <= 5) {
          print(
            'Parent level $level: ${current.localName} classes: ${current.classes}',
          );
          current = current.parent;
          level++;
        }
      }

      // Try to find a common parent that contains both product name and price
      print('\n🎯 Looking for product containers...');

      // Check for article, li, div elements that might be product containers
      final possibleContainers = [
        'article',
        'li',
        '.grid__item',
        '.product-item',
        '.collection-product-card',
        '.card',
      ];

      for (final selector in possibleContainers) {
        final containers = document.querySelectorAll(selector);
        if (containers.isNotEmpty) {
          print('\n$selector: ${containers.length} elements');
          for (int i = 0; i < containers.length && i < 3; i++) {
            final container = containers[i];
            final hasProductLink =
                container.querySelector('a[href*="/products/"]') != null;
            final hasPrice =
                container.querySelector('.price, .price-item') != null;
            if (hasProductLink || hasPrice) {
              print(
                '  Container ${i + 1}: hasLink=$hasProductLink, hasPrice=$hasPrice',
              );
              if (hasProductLink && hasPrice) {
                print('    ✅ This could be our product container!');
                final link = container.querySelector('a[href*="/products/"]');
                final price = container.querySelector('.price-item');
                print('    Name: "${link?.text.trim()}"');
                print('    Price: "${price?.text.trim()}"');
              }
            }
          }
        }
      }

      // Let's see if we can work backwards from h3 elements (which had names)
      print('\n🏷️ Analyzing h3 elements...');
      final h3Elements = document.querySelectorAll('h3');
      for (int i = 0; i < h3Elements.length; i++) {
        final h3 = h3Elements[i];
        print('\nH3 ${i + 1}: "${h3.text.trim()}"');

        // Find the parent that contains both name and price
        var current = h3.parent;
        int level = 1;
        while (current != null && level <= 5) {
          final hasPrice = current.querySelector('.price, .price-item') != null;
          final hasLink =
              current.querySelector('a[href*="/products/"]') != null;
          print(
            '  Parent level $level (${current.localName}): hasPrice=$hasPrice, hasLink=$hasLink, classes=${current.classes}',
          );

          if (hasPrice && hasLink) {
            print('    ✅ Found product container at level $level!');
            break;
          }

          current = current.parent;
          level++;
        }
      }
    } else {
      print('❌ Failed to fetch page: ${response.statusCode}');
    }
  } catch (e) {
    print('💥 Error: $e');
  }
}
