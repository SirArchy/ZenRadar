// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

Future<void> debugIppodoProducts() async {
  print('=== Debugging Ippodo Product Elements ===');

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

      // Focus on elements with data-product-id since we found 17 of them
      final productElements = document.querySelectorAll('[data-product-id]');
      print('Found ${productElements.length} elements with data-product-id');

      if (productElements.isNotEmpty) {
        for (
          int i = 0;
          i < (productElements.length > 3 ? 3 : productElements.length);
          i++
        ) {
          final product = productElements[i];
          print('\n=== Product ${i + 1} ===');
          print('Classes: ${product.attributes['class']}');
          print('Data-product-id: ${product.attributes['data-product-id']}');
          print('HTML (first 500 chars):');
          print(
            '${product.outerHtml.substring(0, product.outerHtml.length > 500 ? 500 : product.outerHtml.length)}...',
          );

          // Try to find name
          final nameSelectors = [
            '.card__heading a',
            '.card__heading',
            'h3 a',
            'h3',
            '.product-title',
            '.product-name',
            'a[href*="/products/"]',
            'a',
            '.card-title',
            '.title',
          ];

          for (String nameSelector in nameSelectors) {
            final nameEl = product.querySelector(nameSelector);
            if (nameEl != null && nameEl.text.trim().isNotEmpty) {
              print('Name found with "$nameSelector": "${nameEl.text.trim()}"');
              break;
            }
          }

          // Try to find price
          final priceSelectors = [
            '.price__current .price-item--regular',
            '.price .price-item',
            '.price',
            '.cost',
            '.money',
            '[class*="price"]',
            '.price-current',
            '.product-price',
          ];

          for (String priceSelector in priceSelectors) {
            final priceEl = product.querySelector(priceSelector);
            if (priceEl != null && priceEl.text.trim().isNotEmpty) {
              print(
                'Price found with "$priceSelector": "${priceEl.text.trim()}"',
              );
              break;
            }
          }

          // Find all links in this product
          final links = product.querySelectorAll('a');
          for (int j = 0; j < links.length; j++) {
            final link = links[j];
            final href = link.attributes['href'] ?? '';
            final text = link.text.trim();
            if (href.isNotEmpty || text.isNotEmpty) {
              print('Link ${j + 1}: href="$href", text="$text"');
            }
          }
        }
      }

      // Also check if there's a grid or collection structure
      print('\n=== Checking for grid/collection structure ===');
      final possibleContainers = [
        '.collection',
        '.product-grid',
        '.grid',
        '.products',
        '.collection-grid',
        '.product-list',
        '.collection-list',
        '.main-collection',
      ];

      for (String selector in possibleContainers) {
        final containers = document.querySelectorAll(selector);
        if (containers.isNotEmpty) {
          print('Container "$selector": ${containers.length} found');
          final container = containers[0];
          final products = container.querySelectorAll('[data-product-id]');
          print('  Contains ${products.length} products with data-product-id');
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
  await debugIppodoProducts();
}
