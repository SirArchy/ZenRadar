// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await debugShoCha();
}

Future<void> debugShoCha() async {
  print('=== Debugging Sho-Cha Website ===');

  try {
    final response = await http.get(
      Uri.parse('https://www.sho-cha.com/teeshop'),
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

    // Check for various product container patterns (Squarespace patterns)
    final containerPatterns = [
      '.ProductList-item',
      '.ProductList-grid .ProductList-item',
      '.product-item',
      '.product-card',
      '.grid-item',
      '.sqs-gallery-block-grid .slide',
      '.ProductList',
      '[class*="ProductList"]',
      '[class*="product"]',
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
          print('ID: ${element.id}');

          // Look for product name
          final nameSelectors = [
            '.ProductList-title a',
            '.ProductList-title',
            '.product-title',
            '.product-name',
            'h3',
            'h4',
            'a',
          ];

          for (final nameSelector in nameSelectors) {
            final nameElement = element.querySelector(nameSelector);
            if (nameElement != null && nameElement.text.trim().isNotEmpty) {
              print('Name ($nameSelector): "${nameElement.text.trim()}"');
              final href = nameElement.attributes['href'];
              if (href != null) {
                print('Link: $href');
              }
              break;
            }
          }

          // Look for price - test various Squarespace price patterns
          final priceSelectors = [
            '.ProductList-price .sqs-money-native',
            '.ProductList-price',
            '.sqs-money-native',
            '.price',
            '.product-price',
            '[class*="price"]',
            '[data-currency-code]',
            '.ProductList-price span',
            '.money',
          ];

          for (final priceSelector in priceSelectors) {
            final priceElements = element.querySelectorAll(priceSelector);
            for (int j = 0; j < priceElements.length; j++) {
              final priceElement = priceElements[j];
              final priceText = priceElement.text.trim();
              final currency = priceElement.attributes['data-currency-code'];
              if (priceText.isNotEmpty) {
                print(
                  'Price ($priceSelector[$j]): "$priceText" ${currency != null ? "(currency: $currency)" : ""}',
                );
                print('  Price element HTML: ${priceElement.outerHtml}');
              }
            }
          }

          print('HTML (first 400 chars):');
          print(
            element.outerHtml.length > 400
                ? '${element.outerHtml.substring(0, 400)}...'
                : element.outerHtml,
          );
          print('');
        }

        // If we found products with this pattern, analyze this one
        if (elements.isNotEmpty) {
          break;
        }
      }
    }

    // Also look for general Squarespace patterns
    print('\n=== Squarespace Structure Analysis ===');
    final productList = document.querySelector('.ProductList');
    if (productList != null) {
      print('Found ProductList container');
      print('ProductList classes: ${productList.classes.join(', ')}');

      final items = productList.querySelectorAll('.ProductList-item');
      print('Items in ProductList: ${items.length}');

      if (items.isNotEmpty) {
        final firstItem = items[0];
        print('\nFirst item analysis:');
        print('Item classes: ${firstItem.classes.join(', ')}');

        // Check all child elements for price patterns
        final allSpans = firstItem.querySelectorAll('span');
        print('All spans in first item:');
        for (int i = 0; i < allSpans.length && i < 10; i++) {
          final span = allSpans[i];
          final text = span.text.trim();
          if (text.isNotEmpty) {
            print(
              '  Span ${i + 1}: "$text" (classes: ${span.classes.join(', ')})',
            );
          }
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
