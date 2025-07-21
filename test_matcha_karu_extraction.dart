// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await testMatchaKaruExtraction();
}

Future<void> testMatchaKaruExtraction() async {
  print('=== Testing Matcha Kāru Product Extraction ===');

  try {
    final response = await http.get(
      Uri.parse('https://matcha-karu.com/collections/matcha-tee'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      },
    );

    if (response.statusCode != 200) {
      print('Failed to fetch page: ${response.statusCode}');
      return;
    }

    final document = html_parser.parse(response.body);

    // Test the exact configuration we're using
    final products = document.querySelectorAll('.product-item');
    print('Found ${products.length} products');

    int extractedCount = 0;
    for (int i = 0; i < Math.min(5, products.length); i++) {
      final product = products[i];

      // Extract name using current selector
      final nameElement1 = product.querySelector('.product-item-meta__title');
      final nameElement2 = product.querySelector('.product-item__info a');
      final name = nameElement1?.text.trim() ?? nameElement2?.text.trim() ?? '';

      // Test different price selectors
      final priceSelectors = [
        '.price:first-child',
        '.price',
        '.price-list .price',
        '.product-item-meta__price-list-container .price',
      ];

      String bestPrice = '';
      String bestSelector = '';

      for (final selector in priceSelectors) {
        final priceElement = product.querySelector(selector);
        final priceText = priceElement?.text.trim() ?? '';

        if (priceText.isNotEmpty) {
          print('Price selector "$selector": "$priceText"');

          // Test cleaning
          String cleanedPrice = cleanMatchaKaruPrice(priceText);
          print('  Cleaned: "$cleanedPrice"');

          if (cleanedPrice.isNotEmpty &&
              cleanedPrice != '00€' &&
              bestPrice.isEmpty) {
            bestPrice = cleanedPrice;
            bestSelector = selector;
          }
        }
      }

      // Extract link
      final linkElement = product.querySelector(
        '.product-item-meta__title, .product-item__info a',
      );
      final link = linkElement?.attributes['href'] ?? '';

      if (name.isNotEmpty && bestPrice.isNotEmpty) {
        extractedCount++;
        print('✅ Product ${i + 1}:');
        print('  Name: "$name"');
        print('  Price: "$bestPrice" (from $bestSelector)');
        print('  Link: $link');
        print('');
      } else {
        print('❌ Product ${i + 1}: Missing data');
        print('  Name: "$name" (${name.isEmpty ? "MISSING" : "OK"})');
        print(
          '  Price: "$bestPrice" (${bestPrice.isEmpty ? "MISSING" : "OK"})',
        );
        print('');
      }
    }

    print(
      'Successfully extracted $extractedCount out of ${Math.min(5, products.length)} test products',
    );

    if (extractedCount > 0) {
      print('✅ Matcha Kāru price extraction needs optimization');
    } else {
      print('❌ Matcha Kāru price extraction failed completely');
    }
  } catch (e) {
    print('Error: $e');
  }
}

String cleanMatchaKaruPrice(String price) {
  String cleaned = price.trim();

  if (cleaned.isEmpty) return '';

  // For Matcha Kāru, handle German price formatting
  // Example: "AngebotspreisAb 19,00 €" -> "19,00 €"
  cleaned = cleaned.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

  // Remove German text prefixes
  cleaned = cleaned.replaceAll('Angebotspreis', '');
  cleaned = cleaned.replaceAll('Ab ', '');
  cleaned = cleaned.replaceAll('ab ', '');
  cleaned = cleaned.trim();

  // Extract price with Euro symbol
  final priceMatch = RegExp(r'(\d+[.,]\d+)\s*€').firstMatch(cleaned);
  if (priceMatch != null) {
    return '${priceMatch.group(1)}€';
  }

  // Fallback: just clean up the string
  if (cleaned == '00' || cleaned == '0' || cleaned.startsWith('00 ')) {
    return '';
  }

  return cleaned;
}

class Math {
  static int min(int a, int b) => a < b ? a : b;
}
