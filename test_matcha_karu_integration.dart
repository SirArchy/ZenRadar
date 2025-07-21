// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await testMatchaKaruIntegration();
}

Future<void> testMatchaKaruIntegration() async {
  print('=== Testing Matcha Kāru Integration (Full Pipeline) ===');

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
      print('❌ Failed to fetch page: ${response.statusCode}');
      return;
    }

    final document = html_parser.parse(response.body);

    // Use exact configuration from crawler_service.dart
    final products = document.querySelectorAll('.product-item');
    print('Found ${products.length} total products');

    int validProducts = 0;

    for (int i = 0; i < Math.min(5, products.length); i++) {
      final product = products[i];

      // Extract name
      final nameElement1 = product.querySelector('.product-item-meta__title');
      final nameElement2 = product.querySelector('.product-item__info a');
      final name = nameElement1?.text.trim() ?? nameElement2?.text.trim() ?? '';

      // Extract price using current selector
      final priceElement = product.querySelector('.price:first-child');
      final rawPrice = priceElement?.text.trim() ?? '';

      // Extract link
      final linkElement = product.querySelector(
        '.product-item-meta__title, .product-item__info a',
      );
      String link = linkElement?.attributes['href'] ?? '';
      if (link.isNotEmpty && !link.startsWith('http')) {
        link = 'https://matcha-karu.com$link';
      }

      // Test stock availability logic
      bool isInStock = false;
      if (priceElement != null && priceElement.text.trim().isNotEmpty) {
        final elementText = product.text.toLowerCase();
        isInStock =
            !elementText.contains('ausverkauft') &&
            !elementText.contains('out of stock') &&
            !elementText.contains('sold out');
      }

      // Test updated price cleaning logic
      String cleanedPrice = cleanPrice(rawPrice, 'matcha-karu');

      if (name.isNotEmpty && cleanedPrice.isNotEmpty && isInStock) {
        validProducts++;
        print('✅ Product ${i + 1}:');
        print('  Name: "$name"');
        print('  Raw Price: "$rawPrice"');
        print('  Cleaned Price: "$cleanedPrice"');
        print('  In Stock: $isInStock');
        print('  Link: $link');
        print('');
      } else {
        print('❌ Product ${i + 1}: Issues detected');
        print('  Name: "$name" (${name.isEmpty ? "MISSING" : "OK"})');
        print('  Raw Price: "$rawPrice"');
        print(
          '  Cleaned Price: "$cleanedPrice" (${cleanedPrice.isEmpty ? "MISSING" : "OK"})',
        );
        print('  In Stock: $isInStock');
        print('');
      }
    }

    print('=== Summary ===');
    print('Total products found: ${products.length}');
    print(
      'Valid products extracted: $validProducts/${Math.min(5, products.length)}',
    );

    if (validProducts > 0) {
      print('✅ Matcha Kāru integration working correctly!');
    } else {
      print('❌ Matcha Kāru integration has issues');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

String cleanPrice(String price, String siteName) {
  String cleaned = price.trim();

  if (cleaned.isEmpty) return '';

  switch (siteName) {
    case 'matcha-karu':
      // For Matcha Kāru, handle German price formatting
      // Example: "AngebotspreisAb 19,00 €" -> "19,00 €"
      cleaned = cleaned.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

      // Remove German text prefixes
      cleaned = cleaned.replaceAll('Angebotspreis', '');
      cleaned = cleaned.replaceAll('Ab ', '');
      cleaned = cleaned.replaceAll('ab ', '');
      cleaned = cleaned.trim();

      // Extract price with Euro symbol and maintain proper spacing
      final priceMatch = RegExp(r'(\d+[.,]\d+)\s*€').firstMatch(cleaned);
      if (priceMatch != null) {
        return '${priceMatch.group(1)} €'; // Add space before Euro symbol
      }

      // Fallback: if it contains a price-like pattern, try to extract it
      final fallbackMatch = RegExp(r'(\d+[.,]\d+)').firstMatch(cleaned);
      if (fallbackMatch != null) {
        return '${fallbackMatch.group(1)} €';
      }

      // Fallback: just clean up the string
      if (cleaned == '00' || cleaned == '0' || cleaned.startsWith('00 ')) {
        return '';
      }
      break;
  }

  return cleaned;
}

class Math {
  static int min(int a, int b) => a < b ? a : b;
}
