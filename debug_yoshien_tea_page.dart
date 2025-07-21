// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await debugYoshienTeaPage();
}

Future<void> debugYoshienTeaPage() async {
  print('=== Debugging Yoshi En Matcha Tea Page ===');

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
    print(
      'Page title: "${document.head?.querySelector('title')?.text ?? 'No title'}"',
    );

    // Check for various product container patterns
    final containerPatterns = [
      '.cs-product-tile',
      '.product-tile',
      '.product-item',
      '.product-card',
      '.grid-item',
      '[class*="product"]',
      '.cs-product',
    ];

    for (final pattern in containerPatterns) {
      final elements = document.querySelectorAll(pattern);
      if (elements.isNotEmpty) {
        print('\nContainer "$pattern": ${elements.length} found');

        // Analyze first few products
        for (int i = 0; i < Math.min(3, elements.length); i++) {
          final element = elements[i];
          print('=== Product ${i + 1} ===');
          print('Classes: ${element.classes.join(', ')}');

          // Look for product name
          final nameSelectors = [
            'a[href*="/matcha-"]',
            '.cs-product-tile__title',
            '.product-name',
            '.product-title',
            'h3',
            'h4',
            '.title',
          ];

          for (final nameSelector in nameSelectors) {
            final nameElement = element.querySelector(nameSelector);
            if (nameElement != null) {
              print('Name ($nameSelector): "${nameElement.text.trim()}"');
              if (nameElement.attributes['href'] != null) {
                print('Link: ${nameElement.attributes['href']}');
              }
              break;
            }
          }

          // Look for price
          final priceSelectors = [
            '.cs-product-tile__price',
            '.price',
            '.product-price',
            '[class*="price"]',
            '.amount',
          ];

          for (final priceSelector in priceSelectors) {
            final priceElement = element.querySelector(priceSelector);
            if (priceElement != null) {
              print('Price ($priceSelector): "${priceElement.text.trim()}"');
              break;
            }
          }

          // Look for stock/availability
          final stockSelectors = [
            '.stock',
            '.availability',
            '[class*="stock"]',
            '[class*="available"]',
            '.cs-product-tile__stock',
          ];

          for (final stockSelector in stockSelectors) {
            final stockElement = element.querySelector(stockSelector);
            if (stockElement != null) {
              print('Stock ($stockSelector): "${stockElement.text.trim()}"');
              break;
            }
          }

          print('HTML (first 200 chars):');
          print(
            element.outerHtml.length > 200
                ? '${element.outerHtml.substring(0, 200)}...'
                : element.outerHtml,
          );
          print('');
        }
        break; // Found products, no need to check other patterns
      }
    }

    // Also check for main product grid
    final productGrids = document.querySelectorAll(
      '.cs-listing-products, .products, [class*="product-grid"], .grid',
    );
    for (final grid in productGrids) {
      if (grid.children.isNotEmpty) {
        print('\nProduct grid found: ${grid.classes.join(', ')}');
        print('Grid children: ${grid.children.length}');
        final firstChild = grid.children.first;
        print('First child classes: ${firstChild.classes.join(', ')}');
        print('First child HTML (first 300 chars):');
        print(
          firstChild.outerHtml.length > 300
              ? '${firstChild.outerHtml.substring(0, 300)}...'
              : firstChild.outerHtml,
        );
        break;
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}

class Math {
  static int min(int a, int b) => a < b ? a : b;
}
