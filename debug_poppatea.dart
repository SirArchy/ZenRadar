// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  print('🔍 Analyzing Poppatea website structure...\n');

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

      print('🌐 Page Title: ${document.querySelector('title')?.text}');
      print('📄 Page Length: ${response.body.length} characters\n');

      // Try common Shopify product selectors
      final shopifySelectors = [
        '.product-item',
        '.product-card',
        '.card-wrapper',
        '.grid__item',
        '.product',
        '.collection-product-card',
        '[data-product-item]',
        '.product-list-item',
      ];

      print('🔍 Testing product container selectors:');
      for (final selector in shopifySelectors) {
        final elements = document.querySelectorAll(selector);
        print('  $selector: ${elements.length} elements');

        if (elements.isNotEmpty) {
          print('    First element classes: ${elements.first.classes}');
          if (elements.first.text.trim().isNotEmpty) {
            final text = elements.first.text.trim();
            final preview =
                text.length > 100 ? '${text.substring(0, 100)}...' : text;
            print('    Preview: "$preview"');
          }
        }
      }

      // Try to find product names
      print('\n🏷️ Testing name selectors:');
      final nameSelectors = [
        '.product-item__title',
        '.card__heading',
        '.product-title',
        '.product-name',
        'h3',
        'h2',
        '.product-card__title',
        '.collection-product-card__title',
      ];

      for (final selector in nameSelectors) {
        final elements = document.querySelectorAll(selector);
        print('  $selector: ${elements.length} elements');
        if (elements.isNotEmpty) {
          for (int i = 0; i < elements.length && i < 3; i++) {
            final text = elements[i].text.trim();
            if (text.isNotEmpty) {
              print('    "$text"');
            }
          }
        }
      }

      // Try to find prices
      print('\n💰 Testing price selectors:');
      final priceSelectors = [
        '.price',
        '.product-price',
        '.price__current',
        '.price-item',
        '.money',
        '.product-item__price',
        '.card__price',
        '.collection-product-card__price',
      ];

      for (final selector in priceSelectors) {
        final elements = document.querySelectorAll(selector);
        print('  $selector: ${elements.length} elements');
        if (elements.isNotEmpty) {
          for (int i = 0; i < elements.length && i < 3; i++) {
            final text = elements[i].text.trim();
            if (text.isNotEmpty && text.contains('€')) {
              print('    "$text"');
            }
          }
        }
      }

      // Try to find stock indicators
      print('\n📦 Testing stock selectors:');
      final stockSelectors = [
        '.product-form__buttons',
        '.product-form__cart',
        'form[action*="cart"]',
        '.btn',
        'button[type="submit"]',
        '.add-to-cart',
        '.product-form',
        '.variant-picker',
      ];

      for (final selector in stockSelectors) {
        final elements = document.querySelectorAll(selector);
        print('  $selector: ${elements.length} elements');
      }

      // Check for "AUSVERKAUFT" text
      if (response.body.contains('AUSVERKAUFT')) {
        print('\n❌ Found "AUSVERKAUFT" (sold out) text in page');
      }

      // Look for specific product structure
      print('\n🎯 Looking for actual product structure...');
      final productItems = document.querySelectorAll('a[href*="/products/"]');
      print('Product links found: ${productItems.length}');

      for (int i = 0; i < productItems.length && i < 5; i++) {
        final item = productItems[i];
        print('\nProduct ${i + 1}:');
        print('  Link: ${item.attributes['href']}');
        print('  Classes: ${item.classes}');
        print('  Parent classes: ${item.parent?.classes}');

        // Check if this link contains product info
        final text = item.text.trim();
        if (text.isNotEmpty) {
          final preview =
              text.length > 50 ? '${text.substring(0, 50)}...' : text;
          print('  Text: "$preview"');
        }
      }
    } else {
      print('❌ Failed to fetch page: ${response.statusCode}');
    }
  } catch (e) {
    print('💥 Error: $e');
  }
}
