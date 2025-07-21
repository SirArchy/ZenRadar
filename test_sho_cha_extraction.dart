// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await testShoChaExtraction();
}

Future<void> testShoChaExtraction() async {
  print('=== Testing Sho-Cha Product Extraction ===');

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
      print('Failed to fetch page: ${response.statusCode}');
      return;
    }

    final document = html_parser.parse(response.body);

    // Test the exact configuration we're using
    final products = document.querySelectorAll('.ProductList-item');
    print('Found ${products.length} products');

    int extractedCount = 0;
    for (int i = 0; i < Math.min(10, products.length); i++) {
      final product = products[i];

      // Extract name using current selector
      final nameElement = product.querySelector(
        '.ProductList-title a, .ProductList-title',
      );
      final name = nameElement?.text.trim() ?? '';

      // Extract price using updated selector
      final priceElement = product.querySelector('.product-price');
      final priceText = priceElement?.text.trim() ?? '';

      // Extract link
      final linkElement = product.querySelector('.ProductList-title a, a');
      final link = linkElement?.attributes['href'] ?? '';

      // Clean price (remove non-breaking spaces and normalize)
      String cleanPrice =
          priceText
              .replaceAll('\u00A0', ' ') // Replace non-breaking space
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();

      if (name.isNotEmpty && cleanPrice.isNotEmpty) {
        extractedCount++;
        print('Product ${i + 1}:');
        print('  Name: "$name"');
        print('  Price: "$cleanPrice"');
        print('  Raw price: "${priceText.codeUnits}"'); // Show raw chars
        print('  Link: $link');
        print('');
      } else {
        print(
          'Product ${i + 1}: Missing data - Name: "$name", Price: "$cleanPrice"',
        );
      }
    }

    print(
      'Successfully extracted $extractedCount out of ${Math.min(10, products.length)} test products',
    );

    if (extractedCount > 0) {
      print('✅ Sho-Cha price extraction is working correctly!');
    } else {
      print('❌ Sho-Cha price extraction failed');
    }
  } catch (e) {
    print('Error: $e');
  }
}

class Math {
  static int min(int a, int b) => a < b ? a : b;
}
