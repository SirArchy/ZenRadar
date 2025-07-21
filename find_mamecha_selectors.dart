// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await findMamechaProductSelectors();
}

Future<void> findMamechaProductSelectors() async {
  print('=== Finding Mamecha Product Selectors ===');

  try {
    final response = await http.get(
      Uri.parse('https://www.mamecha.com/online-shopping-1/'),
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

    // Look for product containers that contain matcha-related content
    final potentialSelectors = [
      '[id*="cc-m-product"]',
      '[class*="cc-m-product"]',
      '.cc-product',
      '[data-product-id]',
      '.module_product',
      '[id*="product"]',
    ];

    for (final selector in potentialSelectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        print('\n✅ Product container "$selector": ${elements.length} found');

        // Check first few for structure
        for (int i = 0; i < Math.min(3, elements.length); i++) {
          final element = elements[i];
          final text = element.text.toLowerCase();

          // Only analyze elements that contain matcha or tea content
          if (text.contains('matcha') ||
              text.contains('sencha') ||
              text.contains('hojicha')) {
            print('\n--- Product ${i + 1} Structure ---');
            print('Element ID: ${element.id}');
            print('Element classes: ${element.classes.join(', ')}');

            // Look for product name
            final nameSelectors = [
              'h2',
              'h3',
              'h4',
              '.product-title',
              '.title',
              '[class*="title"]',
              '.product-name',
              '.name',
              '[class*="name"]',
              'strong',
            ];

            String? productName;
            for (final nameSelector in nameSelectors) {
              final nameElement = element.querySelector(nameSelector);
              if (nameElement != null && nameElement.text.trim().isNotEmpty) {
                final nameText = nameElement.text.trim();
                if (nameText.length > 2 &&
                    nameText.length < 50 &&
                    !nameText.contains('€')) {
                  productName = nameText;
                  print('✅ Name with "$nameSelector": "$nameText"');
                  break;
                }
              }
            }

            // Look for price
            final priceSelectors = [
              '.price',
              '[class*="price"]',
              '.amount',
              '.cost',
              'span',
              'div',
            ];

            for (final priceSelector in priceSelectors) {
              final priceElements = element.querySelectorAll(priceSelector);
              for (final priceElement in priceElements) {
                final priceText = priceElement.text.trim();
                if (priceText.contains('€') && priceText.length < 30) {
                  print('✅ Price with "$priceSelector": "$priceText"');
                  break;
                }
              }
            }

            // Look for links
            final linkElements = element.querySelectorAll('a[href]');
            for (final linkElement in linkElements) {
              final href = linkElement.attributes['href'];
              if (href != null &&
                  (href.contains('product') || href.contains('matcha'))) {
                print('✅ Product link: "$href"');
                break;
              }
            }

            // Look for stock information
            final stockIndicators = [
              'verfügbar',
              'ausverkauft',
              'available',
              'out of stock',
            ];
            for (final indicator in stockIndicators) {
              if (text.contains(indicator)) {
                print('✅ Stock indicator: "$indicator"');
                break;
              }
            }

            if (productName != null) {
              break; // Found a good example
            }
          }
        }

        if (elements.isNotEmpty) {
          break; // Found products, don't need to check other selectors
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}

class Math {
  static int min(int a, int b) => a < b ? a : b;
}
