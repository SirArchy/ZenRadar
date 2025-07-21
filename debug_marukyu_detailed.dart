// Debug script for Marukyu-Koyamaen - detailed analysis
// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

void main() async {
  print('🔍 Detailed Marukyu-Koyamaen analysis...');

  const url =
      'https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha?currency=USD';

  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );

    if (response.statusCode == 200) {
      final document = parse(response.body);

      // Focus on .products container
      final productsContainer = document.querySelector('.products');
      if (productsContainer != null) {
        print(
          '📦 Found .products container with ${productsContainer.children.length} children',
        );

        // Analyze the first few children
        for (int i = 0; i < productsContainer.children.length && i < 3; i++) {
          final child = productsContainer.children[i];
          print('\n🔍 Child $i:');
          print('  Tag: ${child.localName}');
          print('  Classes: ${child.classes}');
          print('  Attributes: ${child.attributes.keys.toList()}');

          // Look for name selectors
          final nameSelectors = [
            '.item-name',
            '.product-name',
            '.name',
            'h3',
            'h2',
            'h1',
            '.title',
            'a',
          ];
          for (String selector in nameSelectors) {
            final nameElement = child.querySelector(selector);
            if (nameElement != null) {
              final text = nameElement.text.trim();
              if (text.isNotEmpty) {
                print('  Name ($selector): "$text"');
              }
            }
          }

          // Look for price selectors
          final priceSelectors = [
            '.price',
            '.item-price',
            '.cost',
            '.amount',
            '.woocommerce-Price-amount',
          ];
          for (String selector in priceSelectors) {
            final priceElement = child.querySelector(selector);
            if (priceElement != null) {
              final text = priceElement.text.trim();
              if (text.isNotEmpty) {
                print('  Price ($selector): "$text"');
              }
            }
          }

          // Look for link selectors
          final linkSelectors = ['a', '.item-link', '.product-link'];
          for (String selector in linkSelectors) {
            final linkElement = child.querySelector(selector);
            if (linkElement != null) {
              final href = linkElement.attributes['href'];
              if (href != null && href.isNotEmpty) {
                print('  Link ($selector): "$href"');
              }
            }
          }

          // Look for stock indicators
          final stockSelectors = [
            '.cart-form button',
            '.add-to-cart',
            '.stock',
            '.availability',
            'button',
          ];
          for (String selector in stockSelectors) {
            final stockElement = child.querySelector(selector);
            if (stockElement != null) {
              final text = stockElement.text.trim();
              final disabled = stockElement.attributes['disabled'];
              print('  Stock ($selector): text="$text", disabled=$disabled');
            }
          }

          // Show the full text content for context
          final fullText = child.text.trim();
          if (fullText.length > 200) {
            print('  Full text preview: "${fullText.substring(0, 200)}..."');
          } else {
            print('  Full text: "$fullText"');
          }
        }
      }

      // Also check if there are direct product elements
      final productElements = document.querySelectorAll('.product');
      print('\n🛒 Found ${productElements.length} .product elements');

      if (productElements.isNotEmpty) {
        final firstProduct = productElements.first;
        print('\nFirst .product element:');
        print('  Classes: ${firstProduct.classes}');
        print('  Children count: ${firstProduct.children.length}');

        // Check if it's actually a product or something else
        final innerHTML = firstProduct.innerHtml;
        if (innerHTML.length > 300) {
          print('  HTML preview: "${innerHTML.substring(0, 300)}..."');
        } else {
          print('  Full HTML: "$innerHTML"');
        }
      }
    } else {
      print('❌ Failed to fetch page: ${response.statusCode}');
    }
  } catch (e) {
    print('💥 Error: $e');
  }
}
