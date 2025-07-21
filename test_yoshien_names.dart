// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await testYoshienProducts();
}

Future<void> testYoshienProducts() async {
  print('=== Testing Yoshi En Product Name Extraction ===');

  try {
    final response = await http.get(
      Uri.parse('https://www.yoshien.com/matcha/matcha-tee/'),
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
    final products = document.querySelectorAll('.cs-product-tile');

    print('Found ${products.length} products');

    int realProducts = 0;
    for (int i = 0; i < products.length && realProducts < 5; i++) {
      final product = products[i];

      // Skip template products
      if (product.classes.contains('article-template') ||
          product.classes.contains('product-template') ||
          product.attributes['style']?.contains('display: none') == true) {
        continue;
      }

      realProducts++;
      print('\n=== Product $realProducts ===');
      print('Classes: ${product.classes.join(', ')}');

      // Test various name selectors
      final nameSelectors = [
        '.cs-product-tile__title a',
        '.cs-product-tile__title',
        'a[href*="/matcha-"]',
        '.cs-product-tile__content h3',
        '.cs-product-tile__content a',
        'strong a',
        'h3 a',
        '.product-name',
      ];

      String? productName;
      String? productLink;

      for (final selector in nameSelectors) {
        final element = product.querySelector(selector);
        if (element != null && element.text.trim().isNotEmpty) {
          productName = element.text.trim();
          productLink = element.attributes['href'];
          print('✅ Name found with "$selector": "$productName"');
          if (productLink != null) print('   Link: $productLink');
          break;
        }
      }

      if (productName == null || productName.isEmpty) {
        // Try extracting from image alt attribute
        final imgElement = product.querySelector('img[alt]');
        if (imgElement != null &&
            imgElement.attributes['alt']?.isNotEmpty == true) {
          productName = imgElement.attributes['alt']!.trim();
          print('✅ Name from img alt: "$productName"');
        }
      }

      // Test price selector
      final priceElement = product.querySelector('.cs-product-tile__price');
      if (priceElement != null) {
        print('✅ Price found: "${priceElement.text.trim()}"');
      } else {
        print('❌ No price found');
      }

      // Test link selector
      final linkElement = product.querySelector('a[href*="/matcha-"]');
      if (linkElement != null) {
        print('✅ Link found: "${linkElement.attributes['href']}"');
      } else {
        print('❌ No link found');
      }

      if (productName == null || productName.isEmpty) {
        print('❌ No name found, HTML sample:');
        print(
          product.outerHtml.length > 500
              ? '${product.outerHtml.substring(0, 500)}...'
              : product.outerHtml,
        );
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
