// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await analyzeMamechaProducts();
}

Future<void> analyzeMamechaProducts() async {
  print('=== Analyzing Mamecha Product Structure ===');

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

    // Look for product containers that contain matcha
    final productContainers = [
      '.sqs-block-product',
      '.ProductList-grid .ProductList-item',
      '.sqs-gallery-block-grid .sqs-gallery-block-grid-item',
      '.summary-v2 .summary-item',
      '[class*="product-block"]',
      '[class*="product-item"]',
      '[data-product-id]',
      '.product',
    ];

    for (final containerSelector in productContainers) {
      final containers = document.querySelectorAll(containerSelector);
      if (containers.isNotEmpty) {
        print('\n✅ Container "$containerSelector": ${containers.length} found');

        // Check first few for matcha content
        for (int i = 0; i < Math.min(3, containers.length); i++) {
          final container = containers[i];
          final text = container.text.toLowerCase();
          if (text.contains('matcha') ||
              text.contains('tee') ||
              text.contains('tea')) {
            print('   Product ${i + 1} contains tea/matcha content');
            print('   Classes: ${container.classes.join(', ')}');
            print(
              '   Text sample: "${container.text.trim().substring(0, Math.min(150, container.text.trim().length))}..."',
            );

            // Look for name selectors
            final nameSelectors = [
              'h3',
              'h2',
              '.product-title',
              '.title',
              '[class*="title"]',
              'a[href*="product"]',
              '.product-name',
              '.name',
            ];

            for (final nameSelector in nameSelectors) {
              final nameElement = container.querySelector(nameSelector);
              if (nameElement != null && nameElement.text.trim().isNotEmpty) {
                print(
                  '   Name in "$nameSelector": "${nameElement.text.trim()}"',
                );
                if (nameElement.attributes['href'] != null) {
                  print('   Link: ${nameElement.attributes['href']}');
                }
              }
            }

            // Look for price selectors
            final priceSelectors = [
              '.price',
              '[class*="price"]',
              '.cost',
              '.amount',
              '.ProductList-price',
              '.summary-metadata-item--price',
            ];

            for (final priceSelector in priceSelectors) {
              final priceElement = container.querySelector(priceSelector);
              if (priceElement != null && priceElement.text.trim().isNotEmpty) {
                print(
                  '   Price in "$priceSelector": "${priceElement.text.trim()}"',
                );
              }
            }
            print('');
            break; // Found a good example, move to next container type
          }
        }
      }
    }

    // Also check specific matcha links
    print('\n=== Analyzing Matcha Product Links ===');
    final matchaLinks = document.querySelectorAll(
      'a[href*="matcha"], a[href*="product"]',
    );
    for (int i = 0; i < Math.min(5, matchaLinks.length); i++) {
      final link = matchaLinks[i];
      final href = link.attributes['href'];
      final text = link.text.trim();
      if (text.isNotEmpty &&
          !text.contains('Versandkosten') &&
          text.length > 5) {
        print('Product link ${i + 1}: $href');
        print('  Text: "$text"');
        print('  Parent classes: ${link.parent?.classes.join(', ') ?? 'none'}');
        print('');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}

class Math {
  static int min(int a, int b) => a < b ? a : b;
}
