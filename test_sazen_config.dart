// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await testSazenTeaConfig();
}

Future<void> testSazenTeaConfig() async {
  print('=== Testing Sazen Tea Configuration ===');

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

    // Test new configuration
    final productSelector = '.product';
    final nameSelector = '.product-name';
    final priceSelector = '.product-price';
    final linkSelector = 'a[href*="/products/"]';

    final productElements = document.querySelectorAll(productSelector);
    print('Found ${productElements.length} product elements\n');

    int validProducts = 0;

    for (int i = 0; i < productElements.length && i < 8; i++) {
      final product = productElements[i];

      print('=== PRODUCT ${i + 1} ===');

      // Test name extraction
      final nameElement = product.querySelector(nameSelector);
      final productName = nameElement?.text.trim() ?? 'No name found';
      print('Name: $productName');

      // Test price extraction
      final priceElement = product.querySelector(priceSelector);
      final productPrice = priceElement?.text.trim() ?? 'No price found';
      print('Price: $productPrice');

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

      // Check if product is valid (has name, price, and link)
      final hasName = productName != 'No name found' && productName.isNotEmpty;
      final hasPrice =
          productPrice != 'No price found' && productPrice.contains('\$');
      final hasLink = productLink != null;

      if (hasName && hasPrice && hasLink) {
        validProducts++;
        print('Status: ✅ VALID');
      } else {
        print(
          'Status: ❌ INVALID (missing ${!hasName ? 'name ' : ''}${!hasPrice ? 'price ' : ''}${!hasLink ? 'link' : ''})',
        );
      }

      // Test stock determination
      final elementText = product.text.toLowerCase();
      bool inStock = true;

      if (elementText.contains('out of stock') ||
          elementText.contains('sold out') ||
          elementText.contains('not available')) {
        inStock = false;
      } else if (hasPrice && productPrice.contains('\$')) {
        inStock = true;
      } else {
        inStock = false;
      }

      print('Stock Status: ${inStock ? "In Stock" : "Out of Stock"}');
      print('');
    }

    print('=== SUMMARY ===');
    print('Total products found: ${productElements.length}');
    print('Valid products (name + price + link): $validProducts');
    print('Success rate: ${validProducts > 0 ? "SUCCESS" : "FAILED"}');

    if (validProducts > 0) {
      print('\n✅ New configuration works! Updating crawler...');
    } else {
      print('\n❌ Configuration needs adjustment');
    }
  } catch (e) {
    print('Error during test: $e');
  }
}
