// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  print('🧪 Testing final Poppatea selectors...\n');

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

      // Product containers
      final productContainers = document.querySelectorAll('.card__container');
      print(
        '📦 Product containers (.card__container): ${productContainers.length}',
      );

      // Filter to only those that have both product links and prices
      final validContainers =
          productContainers.where((container) {
            final hasProductLink =
                container.querySelector('a[href*="/products/"]') != null;
            final hasPrice = container.querySelector('.price-item') != null;
            return hasProductLink && hasPrice;
          }).toList();

      print('✅ Valid product containers: ${validContainers.length}\n');

      for (int i = 0; i < validContainers.length; i++) {
        final container = validContainers[i];
        print('--- Product ${i + 1} ---');

        // Product name (from h3 or link text)
        final nameElement = container.querySelector(
          'h3, a[href*="/products/"]',
        );
        final name = nameElement?.text.trim() ?? 'No name';
        print('📝 Name: "$name"');

        // Product URL
        final linkElement = container.querySelector('a[href*="/products/"]');
        final href = linkElement?.attributes['href'] ?? '';
        print('🔗 URL: $href');

        // Price
        final priceElement = container.querySelector('.price-item');
        final price = priceElement?.text.trim() ?? 'No price';
        print('💰 Price: "$price"');

        // Stock status (check for AUSVERKAUFT)
        final containerText = container.text;
        final isInStock = !containerText.contains('AUSVERKAUFT');
        print('📦 Stock: ${isInStock ? "✅ In Stock" : "❌ Out of Stock"}');

        print('');
      }

      print('🎯 Final selector configuration:');
      print('  Product selector: .card__container');
      print('  Name selector: h3, a[href*="/products/"]');
      print('  Price selector: .price-item');
      print('  Link selector: a[href*="/products/"]');
      print('  Stock detection: Check for "AUSVERKAUFT" text');
    } else {
      print('❌ Failed to fetch page: ${response.statusCode}');
    }
  } catch (e) {
    print('💥 Error: $e');
  }
}
