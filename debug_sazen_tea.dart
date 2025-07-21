// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await debugSazenTea();
}

Future<void> debugSazenTea() async {
  print('=== Debugging Sazen Tea Matcha Page ===');

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
    print(
      'Page title: "${document.head?.querySelector('title')?.text ?? 'No title'}"',
    );

    // Check for various product container patterns
    final containerPatterns = [
      'table tr',
      '.product-item',
      '.product-card',
      '.product-list-item',
      '.product',
      '[class*="product"]',
      '.item',
      'li',
      'div[class*="item"]',
    ];

    for (final pattern in containerPatterns) {
      final elements = document.querySelectorAll(pattern);
      if (elements.isNotEmpty) {
        print('\nContainer "$pattern": ${elements.length} found');

        // Analyze first few products
        for (int i = 0; i < Math.min(5, elements.length); i++) {
          final element = elements[i];

          // Skip if this doesn't seem like a product (no link to products)
          final hasProductLink =
              element.querySelector('a[href*="product"]') != null ||
              element.querySelector('a[href*="p1"]') != null;

          if (!hasProductLink && pattern == 'table tr') {
            continue; // Skip table headers and non-product rows
          }

          print('=== Product ${i + 1} ===');
          print('Classes: ${element.classes.join(', ')}');
          print('ID: ${element.id}');

          // Look for product name/link
          final nameSelectors = [
            'a[href*="product"]',
            'a[href*="p1"]',
            'a',
            'td:first-child a',
            'td a',
            '.product-name',
            '.name',
            'h3',
            'h4',
          ];

          String? foundName;
          String? foundLink;
          for (final nameSelector in nameSelectors) {
            final nameElement = element.querySelector(nameSelector);
            if (nameElement != null && nameElement.text.trim().isNotEmpty) {
              foundName = nameElement.text.trim();
              foundLink = nameElement.attributes['href'];
              print('Name ($nameSelector): "$foundName"');
              if (foundLink != null) {
                print('Link: $foundLink');
              }
              break;
            }
          }

          // Look for price
          final priceSelectors = [
            'td',
            '.price',
            '.product-price',
            '[class*="price"]',
            '.amount',
            'td:last-child',
            'td:nth-child(2)',
            'td:nth-child(3)',
          ];

          for (final priceSelector in priceSelectors) {
            final priceElements = element.querySelectorAll(priceSelector);
            for (final priceElement in priceElements) {
              final priceText = priceElement.text.trim();
              if (priceText.contains('\$') ||
                  priceText.contains('€') ||
                  priceText.contains('¥') ||
                  RegExp(r'\d+[\.,]\d+').hasMatch(priceText)) {
                print('Price ($priceSelector): "$priceText"');
                break;
              }
            }
          }

          print('HTML (first 300 chars):');
          print(
            element.outerHtml.length > 300
                ? '${element.outerHtml.substring(0, 300)}...'
                : element.outerHtml,
          );
          print('');

          if (foundName != null) {
            break; // Found valid products, analyze this pattern
          }
        }

        // If we found products with this pattern, don't check others
        if (elements.any(
          (e) =>
              e.querySelector('a[href*="product"]') != null ||
              e.querySelector('a[href*="p1"]') != null,
        )) {
          break;
        }
      }
    }

    // Check for specific table structures
    final tables = document.querySelectorAll('table');
    for (int i = 0; i < tables.length; i++) {
      final table = tables[i];
      print('\n=== TABLE ${i + 1} ===');
      print('Table classes: ${table.classes.join(', ')}');
      print('Table rows: ${table.querySelectorAll('tr').length}');

      final rows = table.querySelectorAll('tr');
      for (int j = 0; j < Math.min(3, rows.length); j++) {
        final row = rows[j];
        final cells = row.querySelectorAll('td, th');
        print('Row ${j + 1}: ${cells.length} cells');
        for (int k = 0; k < cells.length; k++) {
          final cellText = cells[k].text.trim();
          if (cellText.isNotEmpty) {
            print(
              '  Cell ${k + 1}: "${cellText.length > 50 ? '${cellText.substring(0, 50)}...' : cellText}"',
            );
          }
        }

        // Check if this row has product links
        final productLinks = row.querySelectorAll(
          'a[href*="product"], a[href*="p1"]',
        );
        if (productLinks.isNotEmpty) {
          print('  Product links: ${productLinks.length}');
          for (final link in productLinks) {
            print(
              '    Link: ${link.attributes['href']} - "${link.text.trim()}"',
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
