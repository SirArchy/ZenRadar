// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  print('🔧 Refining Poppatea selectors...\n');

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

      // Find all h3 elements with product names
      final h3Elements = document.querySelectorAll('h3');
      print('📝 H3 elements with product names:');

      for (int i = 0; i < h3Elements.length; i++) {
        final h3 = h3Elements[i];
        final text = h3.text.trim();
        print('  H3 ${i + 1}: "$text"');

        // Find the parent container
        var container = h3.parent;
        while (container != null &&
            !container.classes.contains('card__container')) {
          container = container.parent;
        }

        if (container != null) {
          print('    Found container!');

          // Check for price in this container
          final priceElement = container.querySelector('.price-item');
          if (priceElement != null) {
            print('    Price: "${priceElement.text.trim()}"');
          }

          // Check for product link
          final linkElement = container.querySelector('a[href*="/products/"]');
          if (linkElement != null) {
            print('    Link: ${linkElement.attributes['href']}');
          }

          // Check for stock status
          final containerText = container.text;
          if (containerText.contains('AUSVERKAUFT')) {
            print('    Stock: ❌ AUSVERKAUFT');
          } else {
            print('    Stock: ✅ Available');
          }

          print('');
        }
      }

      // Let's try a different approach - find the actual product cards
      print('\n🎯 Alternative approach - finding product cards...');

      // Look for the collection-list
      final collectionList = document.querySelector('.collection-list');
      if (collectionList != null) {
        final items = collectionList.querySelectorAll('.collection-list__item');
        print('Found ${items.length} collection list items');

        for (int i = 0; i < items.length && i < 5; i++) {
          final item = items[i];
          print('\n--- Collection Item ${i + 1} ---');

          // Look for product name
          final nameElement = item.querySelector(
            'h3, .card h3, a[href*="/products/"]',
          );
          if (nameElement != null) {
            print('Name: "${nameElement.text.trim()}"');
          }

          // Look for price
          final priceElement = item.querySelector('.price-item');
          if (priceElement != null) {
            print('Price: "${priceElement.text.trim()}"');
          }

          // Look for link
          final linkElement = item.querySelector('a[href*="/products/"]');
          if (linkElement != null) {
            print('Link: ${linkElement.attributes['href']}');
          }

          // Check stock
          if (item.text.contains('AUSVERKAUFT')) {
            print('Stock: ❌ AUSVERKAUFT');
          } else {
            print('Stock: ✅ Available');
          }
        }
      }
    } else {
      print('❌ Failed to fetch page: ${response.statusCode}');
    }
  } catch (e) {
    print('💥 Error: $e');
  }
}
