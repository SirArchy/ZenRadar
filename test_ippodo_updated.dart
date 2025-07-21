// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

// Simulate the updated crawler logic for Ippodo
String cleanPrice(String rawPrice) {
  if (rawPrice.isEmpty) return rawPrice;
  String cleaned = rawPrice.trim();
  // General cleanup
  cleaned = cleaned.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
  return cleaned.trim();
}

Future<void> testUpdatedIppodo() async {
  print('=== Testing Updated Ippodo Configuration ===');

  try {
    final client = http.Client();
    final response = await client
        .get(
          Uri.parse('https://global.ippodo-tea.co.jp/collections/matcha'),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final document = parse.parse(response.body);

      // Test updated selectors
      final products = document.querySelectorAll('.m-product-card');
      print('✅ Found ${products.length} products with .m-product-card');

      for (int i = 0; i < (products.length > 5 ? 5 : products.length); i++) {
        final product = products[i];
        print('\n=== Testing Product ${i + 1} ===');

        // Test name extraction - try .m-product-card__body a first, then img alt
        String name = '';
        final nameElement = product.querySelector('.m-product-card__body a');
        if (nameElement != null && nameElement.text.trim().isNotEmpty) {
          name = nameElement.text.trim();
          print('✅ Name from .m-product-card__body a: "$name"');
        } else {
          final imgElement = product.querySelector('img');
          if (imgElement != null) {
            name = imgElement.attributes['alt']?.trim() ?? '';
            print('✅ Name from img alt: "$name"');
          }
        }

        // Test price extraction
        final priceElement = product.querySelector('.m-product-card__price');
        String? price;
        if (priceElement != null) {
          price = cleanPrice(priceElement.text.trim());
          print('✅ Price: "$price"');
        }

        // Test link extraction
        final linkElement = product.querySelector('a[href*="/products/"]');
        String? href;
        if (linkElement != null) {
          href = linkElement.attributes['href'];
          print('✅ Link: "$href"');
        }

        // Test stock determination
        final outOfStockElement = product.querySelector('.out-of-stock');
        final isInStock = outOfStockElement == null;
        print('✅ Stock status: ${isInStock ? "In Stock" : "Out of Stock"}');

        // Summary
        if (name.isNotEmpty && price != null && href != null) {
          print('🎯 SUCCESS: Product would be crawled successfully');
          print('   Name: "$name"');
          print('   Price: "$price"');
          print('   URL: https://global.ippodo-tea.co.jp$href');
          print('   In Stock: $isInStock');
        } else {
          print(
            '❌ ISSUE: Missing data - Name: ${name.isEmpty ? "MISSING" : "OK"}, Price: ${price == null ? "MISSING" : "OK"}, Link: ${href == null ? "MISSING" : "OK"}',
          );
        }
      }
    } else {
      print('❌ HTTP ${response.statusCode}');
    }

    client.close();
  } catch (e) {
    print('💥 Error: $e');
  }
}

void main() async {
  await testUpdatedIppodo();
}
