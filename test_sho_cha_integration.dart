// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await testShoChaIntegration();
}

Future<void> testShoChaIntegration() async {
  print('=== Testing Sho-Cha Integration (Full Pipeline) ===');

  try {
    final response = await http.get(
      Uri.parse('https://www.sho-cha.com/teeshop'),
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
    final products = document.querySelectorAll('.ProductList-item');
    print('Found ${products.length} total products');

    int validProducts = 0;

    for (int i = 0; i < Math.min(5, products.length); i++) {
      final product = products[i];

      // Extract name
      final nameElement = product.querySelector(
        '.ProductList-title a, .ProductList-title',
      );
      final name = nameElement?.text.trim() ?? '';

      // Extract price
      final priceElement = product.querySelector('.product-price');
      final rawPrice = priceElement?.text.trim() ?? '';

      // Extract link
      final linkElement = product.querySelector('.ProductList-title a, a');
      String link = linkElement?.attributes['href'] ?? '';
      if (link.isNotEmpty && !link.startsWith('http')) {
        link = 'https://www.sho-cha.com$link';
      }

      // Test stock availability logic
      bool isInStock = false;
      if (priceElement != null && priceElement.text.trim().isNotEmpty) {
        final priceText =
            priceElement.text
                .trim()
                .replaceAll('\u00A0', ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
        isInStock =
            priceText.contains('€') &&
            !priceText.contains('00,00') &&
            priceText != '00';
      }

      // Test price cleaning logic
      String cleanedPrice = cleanPrice(rawPrice, 'sho-cha');

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
      print('✅ Sho-Cha integration working correctly!');
    } else {
      print('❌ Sho-Cha integration has issues');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

String cleanPrice(String price, String siteName) {
  String cleaned = price.trim();

  if (cleaned.isEmpty) return '';

  switch (siteName) {
    case 'sho-cha':
      // For Sho-Cha, handle German Euro formatting
      cleaned =
          cleaned
              .replaceAll('\u00A0', ' ') // Replace non-breaking space
              .replaceAll('\n', ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();

      // Extract price in German format (XX,XX €)
      final priceMatch = RegExp(r'(\d+(?:,\d{2})?\s*€)').firstMatch(cleaned);
      if (priceMatch != null) {
        return priceMatch.group(1)!.trim();
      }

      // Fallback: if it looks like a valid price, keep it
      if (cleaned.contains('€') && !cleaned.contains('00,00')) {
        return cleaned;
      }

      return ''; // Invalid price
  }

  return cleaned;
}

class Math {
  static int min(int a, int b) => a < b ? a : b;
}
