// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  print('🔍 Finding actual Poppatea product grid...\n');

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

      // Look for elements that contain price items
      final priceItems = document.querySelectorAll('.price-item');
      print('💰 Found ${priceItems.length} price items\n');

      for (int i = 0; i < priceItems.length; i++) {
        final priceItem = priceItems[i];
        print('--- Price Item ${i + 1} ---');
        print('Text: "${priceItem.text.trim()}"');

        // Walk up the DOM to find the product container
        var current = priceItem.parent;
        int level = 1;
        while (current != null && level <= 8) {
          final hasH3 = current.querySelector('h3') != null;
          final hasProductLink =
              current.querySelector('a[href*="/products/"]') != null;

          print(
            'Level $level (${current.localName}): hasH3=$hasH3, hasLink=$hasProductLink, classes=${current.classes}',
          );

          if (hasH3 && hasProductLink) {
            print('✅ Found complete product container at level $level!');

            final h3 = current.querySelector('h3')!;
            final link = current.querySelector('a[href*="/products/"]')!;

            print('  Name: "${h3.text.trim()}"');
            print('  Price: "${priceItem.text.trim()}"');
            print('  Link: "${link.attributes['href']}"');
            print('  Container tag: ${current.localName}');
            print('  Container classes: ${current.classes}');
            break;
          }

          current = current.parent;
          level++;
        }
        print('');
      }

      // Also look for any div with class containing 'product' or 'item'
      print('🎯 Looking for product-related containers...');
      final productDivs = document.querySelectorAll(
        'div[class*="product"], div[class*="item"], div[class*="card"]',
      );
      print('Found ${productDivs.length} potential product containers');

      for (int i = 0; i < productDivs.length && i < 10; i++) {
        final div = productDivs[i];
        final hasH3 = div.querySelector('h3') != null;
        final hasPrice = div.querySelector('.price-item') != null;
        final hasLink = div.querySelector('a[href*="/products/"]') != null;

        if (hasH3 && hasPrice && hasLink) {
          print(
            '✅ Product container: ${div.localName} with classes ${div.classes}',
          );
        }
      }
    } else {
      print('❌ Failed to fetch page: ${response.statusCode}');
    }
  } catch (e) {
    print('💥 Error: $e');
  }
}
