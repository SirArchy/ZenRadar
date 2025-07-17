// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

Future<void> getCompleteSelectors(String name, String url) async {
  print('\n=== Complete Selector Analysis for $name ===');

  try {
    final client = http.Client();
    final response = await client
        .get(
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
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final document = parse.parse(response.body);

      if (name == 'Sho-Cha') {
        final products = document.querySelectorAll('.ProductList-item');
        print(
          '✅ Product selector: .ProductList-item (${products.length} found)',
        );

        if (products.isNotEmpty) {
          final firstProduct = products[0];

          // Name selector
          var nameEl = firstProduct.querySelector('.ProductList-title a');
          nameEl ??= firstProduct.querySelector('.ProductList-title');
          if (nameEl != null) {
            print('✅ Name selector: .ProductList-title a, .ProductList-title');
            print('   Sample: "${nameEl.text.trim()}"');
          }

          // Price selector
          var priceEl = firstProduct.querySelector(
            '.ProductList-price .sqs-money-native',
          );
          priceEl ??= firstProduct.querySelector('.ProductList-price');
          if (priceEl != null) {
            print(
              '✅ Price selector: .ProductList-price .sqs-money-native, .ProductList-price',
            );
            print('   Sample: "${priceEl.text.trim()}"');
          }

          // Stock/Add to cart selector
          var stockEl = firstProduct.querySelector(
            '.ProductList-status, .AddToCartForm',
          );
          if (stockEl != null) {
            print('✅ Stock selector: .ProductList-status, .AddToCartForm');
            print('   Sample: "${stockEl.text.trim()}"');
          }

          // Link selector
          var linkEl = firstProduct.querySelector('.ProductList-title a');
          linkEl ??= firstProduct.querySelector('a');
          if (linkEl != null) {
            print('✅ Link selector: .ProductList-title a, a');
            print(
              '   Sample href: "${linkEl.attributes['href'] ?? 'No href'}"',
            );
          }
        }
      }

      if (name == 'Yoshien') {
        // Try different approaches for Yoshien
        var tables = document.querySelectorAll('table');
        for (var table in tables) {
          var rows = table.querySelectorAll('tbody tr');
          if (rows.length > 3) {
            // Likely a product table
            print('✅ Found product table with ${rows.length} rows');
            print('✅ Product selector: table tbody tr');

            if (rows.isNotEmpty) {
              final firstRow = rows[0];
              final cells = firstRow.querySelectorAll('td');

              for (int i = 0; i < cells.length; i++) {
                final cell = cells[i];
                final links = cell.querySelectorAll('a');
                final text = cell.text.trim();

                if (links.isNotEmpty && text.isNotEmpty) {
                  print(
                    '   Cell $i: "${text.length > 50 ? text.substring(0, 50) : text}..."',
                  );
                  for (var link in links) {
                    final href = link.attributes['href'];
                    if (href != null && href.contains('matcha')) {
                      print('     Link: "${link.text.trim()}" -> $href');
                    }
                  }
                }
              }
            }
            break;
          }
        }
      }

      if (name == 'Sazen Tea') {
        // Check for zen-cart or similar patterns
        final productTables = document.querySelectorAll('table');
        for (var table in productTables) {
          final rows = table.querySelectorAll('tr');
          if (rows.length > 5) {
            // Product listing table
            print('✅ Found potential product table with ${rows.length} rows');

            for (int i = 0; i < (rows.length > 5 ? 5 : rows.length); i++) {
              final row = rows[i];
              final productLinks = row.querySelectorAll('a[href*="product"]');

              if (productLinks.isNotEmpty) {
                for (var link in productLinks) {
                  final text = link.text.trim();
                  final href = link.attributes['href'];
                  if (text.isNotEmpty &&
                      text.toLowerCase().contains('matcha')) {
                    print('   Product found: "$text"');
                    print('     Link: $href');

                    // Look for price in same row
                    final rowText = row.text;
                    final priceMatch = RegExp(
                      r'[\$€£¥]\s*\d+[.,]\d+',
                    ).firstMatch(rowText);
                    if (priceMatch != null) {
                      print('     Price: ${priceMatch.group(0)}');
                    }
                    break;
                  }
                }
              }
            }
            break;
          }
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
  await getCompleteSelectors('Sho-Cha', 'https://www.sho-cha.com/teeshop');
  await getCompleteSelectors('Yoshien', 'https://www.yoshien.com/matcha/');
  await getCompleteSelectors(
    'Sazen Tea',
    'https://www.sazentea.com/en/products/c21-matcha',
  );
}
