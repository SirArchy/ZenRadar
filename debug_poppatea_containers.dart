// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  print('🔍 Debugging Poppatea product containers...\n');

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

      final containers = document.querySelectorAll('.collection-list__item');
      print('📦 Found ${containers.length} containers\n');

      for (int i = 0; i < containers.length; i++) {
        final container = containers[i];
        print('--- Container ${i + 1} ---');

        final h3 = container.querySelector('h3');
        print('H3: ${h3?.text.trim() ?? "NOT FOUND"}');

        final priceItem = container.querySelector('.price-item');
        print('Price item: ${priceItem?.text.trim() ?? "NOT FOUND"}');

        final productLink = container.querySelector('a[href*="/products/"]');
        print(
          'Product link: ${productLink?.attributes['href'] ?? "NOT FOUND"}',
        );

        print(
          'Container text preview: "${container.text.trim().substring(0, 100)}..."',
        );
        print('Container classes: ${container.classes}');
        print('');
      }

      // Try alternative approach - look at the actual product cards in the grid
      print('\n🎯 Looking for actual product cards...');

      // Check for any element that has both h3 and price
      final allElements = document.querySelectorAll('*');
      for (final element in allElements) {
        final hasH3 = element.querySelector('h3') != null;
        final hasPrice = element.querySelector('.price-item') != null;
        final hasLink = element.querySelector('a[href*="/products/"]') != null;

        if (hasH3 && hasPrice && hasLink) {
          print(
            '✅ Found valid product container: ${element.localName} with classes ${element.classes}',
          );

          final h3 = element.querySelector('h3')!;
          final price = element.querySelector('.price-item')!;
          final link = element.querySelector('a[href*="/products/"]')!;

          print('  Name: "${h3.text.trim()}"');
          print('  Price: "${price.text.trim()}"');
          print('  Link: "${link.attributes['href']}"');
          break;
        }
      }
    } else {
      print('❌ Failed to fetch page: ${response.statusCode}');
    }
  } catch (e) {
    print('💥 Error: $e');
  }
}
