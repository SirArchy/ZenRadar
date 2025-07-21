// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  print('🔍 Detailed Poppatea structure analysis...\n');

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

      // Look for the main product containers
      print('🎯 Analyzing card elements...');
      final cards = document.querySelectorAll('.card');
      print('Found ${cards.length} card elements\n');

      // Find the product cards specifically (those with product links)
      final productCards =
          cards.where((card) {
            final link = card.querySelector('a[href*="/products/"]');
            return link != null;
          }).toList();

      print('📦 Found ${productCards.length} product cards\n');

      for (int i = 0; i < productCards.length && i < 3; i++) {
        final card = productCards[i];
        print('--- Product ${i + 1} ---');

        // Find product link and name
        final nameLink = card.querySelector('a[href*="/products/"]');
        if (nameLink != null) {
          print('🔗 Link: ${nameLink.attributes['href']}');
          print('📝 Name: "${nameLink.text.trim()}"');
        }

        // Find price information
        final priceElement = card.querySelector('.card__price, .price');
        if (priceElement != null) {
          print('💰 Price element found');
          final priceItems = priceElement.querySelectorAll('.price-item');
          for (final item in priceItems) {
            final priceText = item.text.trim();
            if (priceText.contains('€')) {
              print('    Price: "$priceText"');
            }
          }
        }

        // Check for stock status
        final soldOutBadge = card.querySelector('.card__badge');
        if (soldOutBadge != null) {
          print('🏷️ Badge: "${soldOutBadge.text.trim()}"');
        }

        // Check for "AUSVERKAUFT" text
        final cardText = card.text;
        if (cardText.contains('AUSVERKAUFT')) {
          print('❌ Product marked as AUSVERKAUFT');
        } else {
          print('✅ Product appears to be in stock');
        }

        print('');
      }

      // Test the selectors we'll use
      print('🧪 Testing final selectors...');
      print(
        'Product container: .card (with product link) = ${productCards.length} products',
      );

      final nameSelector = 'a[href*="/products/"]';
      final names = document.querySelectorAll(nameSelector);
      print('Name selector: $nameSelector = ${names.length} names');

      final priceSelector = '.price-item';
      final prices = document.querySelectorAll(priceSelector);
      print('Price selector: $priceSelector = ${prices.length} prices');

      final linkSelector = 'a[href*="/products/"]';
      final links = document.querySelectorAll(linkSelector);
      print('Link selector: $linkSelector = ${links.length} links');

      // Check if page contains "AUSVERKAUFT"
      final pageText = document.body?.text ?? '';
      if (pageText.contains('AUSVERKAUFT')) {
        print(
          '\n❌ Page contains "AUSVERKAUFT" text - we can detect sold out products',
        );
      } else {
        print('\n✅ No "AUSVERKAUFT" text found - all products appear in stock');
      }
    } else {
      print('❌ Failed to fetch page: ${response.statusCode}');
    }
  } catch (e) {
    print('💥 Error: $e');
  }
}
