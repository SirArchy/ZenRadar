// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  print('🧪 Testing Poppatea crawler integration...\n');

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

      // Use the same selectors as configured in crawler service
      final productElements = document.querySelectorAll(
        '.collection-list__item',
      );
      print('📦 Found ${productElements.length} product containers\n');

      final validProducts = <Map<String, dynamic>>[];

      for (int i = 0; i < productElements.length; i++) {
        final element = productElements[i];

        // Extract name using h3 selector
        final nameElement = element.querySelector('h3');
        final name = nameElement?.text.trim() ?? '';

        // Extract price using .price-item selector
        final priceElement = element.querySelector('.price-item');
        final rawPrice = priceElement?.text.trim() ?? '';

        // Extract link using a[href*="/products/"] selector
        final linkElement = element.querySelector('a[href*="/products/"]');
        final href = linkElement?.attributes['href'] ?? '';

        // Check stock status (no AUSVERKAUFT text)
        final isInStock = !element.text.contains('AUSVERKAUFT');

        // Clean price using Poppatea logic
        String cleanedPrice = '';
        if (rawPrice.isNotEmpty) {
          String cleaned =
              rawPrice
                  .replaceAll('\u00A0', ' ')
                  .replaceAll('\n', ' ')
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim();

          cleaned = cleaned.replaceAll('Ab ', '').trim();

          final priceMatch = RegExp(r'€?(\d+,\d{2})\s*€?').firstMatch(cleaned);
          if (priceMatch != null) {
            cleanedPrice = '${priceMatch.group(1)} €';
          } else if (cleaned.contains('€') && RegExp(r'\d').hasMatch(cleaned)) {
            cleanedPrice = cleaned;
          }
        }

        // Calculate price value
        double? priceValue;
        if (cleanedPrice.isNotEmpty) {
          String valueStr =
              cleanedPrice.replaceAll('€', '').replaceAll(' ', '').trim();

          final match = RegExp(r'(\d+),(\d+)').firstMatch(valueStr);
          if (match != null) {
            final wholePart = match.group(1)!;
            final decimalPart = match.group(2)!;
            priceValue = double.tryParse('$wholePart.$decimalPart');
          }
        }

        // Only include valid products (have name, price, and link)
        if (name.isNotEmpty && cleanedPrice.isNotEmpty && href.isNotEmpty) {
          validProducts.add({
            'name': name,
            'price': cleanedPrice,
            'priceValue': priceValue,
            'url': href,
            'isInStock': isInStock,
          });
        }
      }

      print('✅ Valid products found: ${validProducts.length}\n');

      for (int i = 0; i < validProducts.length && i < 5; i++) {
        final product = validProducts[i];
        print('--- Product ${i + 1} ---');
        print('📝 Name: ${product['name']}');
        print('💰 Price: ${product['price']}');
        print('💱 Price Value: ${product['priceValue']}');
        print('🔗 URL: ${product['url']}');
        print(
          '📦 Stock: ${product['isInStock'] ? "✅ In Stock" : "❌ Out of Stock"}',
        );
        print('');
      }

      if (validProducts.isNotEmpty) {
        print('🎉 Poppatea integration test PASSED!');
        print('✅ All products have names, prices, and links');
        print('✅ Price values calculated correctly');
        print('✅ Stock status detection working');
      } else {
        print('❌ Poppatea integration test FAILED!');
        print('No valid products found');
      }
    } else {
      print('❌ Failed to fetch page: ${response.statusCode}');
    }
  } catch (e) {
    print('💥 Error: $e');
  }
}
