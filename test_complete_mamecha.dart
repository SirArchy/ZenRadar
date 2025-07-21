// ignore_for_file: avoid_print

import 'dart:html' as html;
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('Testing complete Mamecha configuration...\n');

  try {
    // Fetch the page
    final response = await http.get(
      Uri.parse('https://mamecha.com/online-shopping-1/'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      },
    );

    if (response.statusCode != 200) {
      print('Failed to fetch page: ${response.statusCode}');
      return;
    }

    // Parse HTML
    final document = html.DomParser().parseFromString(
      response.body,
      'text/html',
    );
    print('Document parsed successfully\n');

    // Find products using updated selector
    final productSelector = '[id*="cc-m-product"]';
    final productElements = document.querySelectorAll(productSelector);
    print('Found ${productElements.length} product elements\n');

    for (int i = 0; i < productElements.length && i < 5; i++) {
      final product = productElements[i];

      print('=== PRODUCT ${i + 1} ===');
      print('Product ID: ${product.id}');

      // Test name extraction
      final nameElement = product.querySelector('h4');
      final productName = nameElement?.text?.trim() ?? 'No name found';
      print('Name: $productName');

      // Test price extraction - try both selectors
      String? price;

      // First try current price
      final currentPriceElement = product.querySelector(
        '.cc-shop-product-price-current',
      );
      final currentPriceText = currentPriceElement?.text?.trim();
      if (currentPriceText != null && currentPriceText.isNotEmpty) {
        price = currentPriceText;
        print('Price from .cc-shop-product-price-current: $price');
      }

      // Then try variant options
      if (price == null || price.isEmpty) {
        final variantElements = product.querySelectorAll(
          'option.j-product__variants__item',
        );
        for (final variant in variantElements) {
          final variantText = variant.text?.trim();
          if (variantText != null &&
              variantText.contains('€') &&
              !variantText.contains('0,00')) {
            price = variantText;
            print('Price from variant option: $price');
            break;
          }
        }
      }

      if (price == null || price.isEmpty) {
        print('Price: NOT FOUND');
      }

      // Test link extraction
      final linkElement = product.querySelector('a');
      final productLink = linkElement?.getAttribute('href');
      if (productLink != null) {
        final fullLink =
            productLink.startsWith('http')
                ? productLink
                : 'https://mamecha.com$productLink';
        print('Link: $fullLink');
      } else {
        print('Link: NOT FOUND');
      }

      // Test stock status
      final elementText = product.text?.toLowerCase() ?? '';
      bool inStock = true;

      if (elementText.contains('out of stock') ||
          elementText.contains('sold out') ||
          elementText.contains('ausverkauft') ||
          elementText.contains('leider ausverkauft')) {
        inStock = false;
      } else if (elementText.contains('verfügbar')) {
        inStock = true;
      } else if (price != null &&
          price.contains('€') &&
          !price.contains('0,00')) {
        inStock = true;
      } else {
        inStock = false;
      }

      print('Stock Status: ${inStock ? "In Stock" : "Out of Stock"}');
      print(
        'Element text snippet: ${elementText.substring(0, elementText.length > 100 ? 100 : elementText.length)}...\n',
      );
    }

    // Summary
    final validProducts =
        productElements.where((product) {
          final nameElement = product.querySelector('h4');
          final nameText = nameElement?.text?.trim();
          final hasName = nameText != null && nameText.isNotEmpty;

          final currentPriceElement = product.querySelector(
            '.cc-shop-product-price-current',
          );
          final currentPriceText = currentPriceElement?.text?.trim();
          final variantElements = product.querySelectorAll(
            'option.j-product__variants__item',
          );

          final hasPrice =
              (currentPriceText != null && currentPriceText.isNotEmpty) ||
              variantElements.any((e) {
                final text = e.text;
                return text != null &&
                    text.contains('€') &&
                    !text.contains('0,00');
              });

          final linkElement = product.querySelector('a');
          final hasLink = linkElement?.getAttribute('href') != null;

          return hasName && hasPrice && hasLink;
        }).length;

    print('=== SUMMARY ===');
    print('Total products found: ${productElements.length}');
    print('Valid products (name + price + link): $validProducts');
    print('Success rate: ${validProducts > 0 ? "SUCCESS" : "FAILED"}');
  } catch (e) {
    print('Error during test: $e');
  }
}
