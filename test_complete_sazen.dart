// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await testCompleteSazenTea();
}

Future<void> testCompleteSazenTea() async {
  print('=== Testing Complete Sazen Tea Configuration ===');

  try {
    final response = await http.get(
      Uri.parse('https://www.sazentea.com/en/products/c21-matcha'),
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
    print('Document parsed successfully\n');

    // Use the exact same configuration as in the crawler
    final productSelector = '.product';
    final nameSelector = '.product-name';
    final priceSelector = '.product-price';
    final linkSelector = 'a[href*="/products/"]';

    final productElements = document.querySelectorAll(productSelector);
    print('Found ${productElements.length} product elements\n');

    int validProducts = 0;

    for (int i = 0; i < productElements.length && i < 5; i++) {
      final product = productElements[i];

      print('=== PRODUCT ${i + 1} ===');

      // Test name extraction
      final nameElement = product.querySelector(nameSelector);
      final productName = nameElement?.text.trim() ?? '';
      print('Name: ${productName.isNotEmpty ? productName : "NOT FOUND"}');

      // Test price extraction with cleaning logic
      final priceElement = product.querySelector(priceSelector);
      String? cleanedPrice;
      if (priceElement != null) {
        final rawPrice = priceElement.text.trim();
        print('Raw price: $rawPrice');

        // Apply the same cleaning logic as the crawler
        final cleanedText = rawPrice
            .replaceAll('\n', ' ')
            .replaceAll(RegExp(r'\s+'), ' ');
        final priceMatch = RegExp(r'\$(\d+\.\d+)').firstMatch(cleanedText);
        if (priceMatch != null) {
          cleanedPrice = '\$${priceMatch.group(1)}';
        }

        print('Cleaned price: ${cleanedPrice ?? "NOT EXTRACTED"}');
      } else {
        print('Price: NOT FOUND');
      }

      // Test link extraction
      final linkElement = product.querySelector(linkSelector);
      final productLink = linkElement?.attributes['href'];
      if (productLink != null) {
        final fullLink =
            productLink.startsWith('http')
                ? productLink
                : 'https://www.sazentea.com$productLink';
        print('Link: $fullLink');
      } else {
        print('Link: NOT FOUND');
      }

      // Test stock determination logic
      final elementText = product.text.toLowerCase();
      bool inStock = true;

      if (elementText.contains('out of stock') ||
          elementText.contains('sold out') ||
          elementText.contains('unavailable')) {
        inStock = false;
      } else if (priceElement != null) {
        final priceText = priceElement.text.trim();
        inStock = priceText.contains('\$') && !priceText.contains('0.00');
      } else {
        inStock = false;
      }

      print('Stock Status: ${inStock ? "In Stock" : "Out of Stock"}');

      // Check if product is valid
      final hasName = productName.isNotEmpty;
      final hasPrice = cleanedPrice != null;
      final hasLink = productLink != null;

      if (hasName && hasPrice && hasLink) {
        validProducts++;
        print('Status: ✅ VALID PRODUCT');
      } else {
        print(
          'Status: ❌ INVALID (missing ${!hasName ? 'name ' : ''}${!hasPrice ? 'price ' : ''}${!hasLink ? 'link' : ''})',
        );
      }
      print('');
    }

    print('=== SUMMARY ===');
    print('Total products found: ${productElements.length}');
    print('Valid products (name + price + link): $validProducts');
    print('Success rate: ${validProducts > 0 ? "✅ SUCCESS" : "❌ FAILED"}');

    if (validProducts > 0) {
      print('\n🎉 Sazen Tea crawler configuration is working correctly!');
      print(
        'Found $validProducts valid matcha products out of ${productElements.length} total products.',
      );
    } else {
      print('\n❌ Configuration needs further adjustment');
    }
  } catch (e) {
    print('Error during test: $e');
  }
}
