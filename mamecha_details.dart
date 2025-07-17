// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

Future<void> analyzeMamechaDetails() async {
  print('\n=== Detailed Mamecha Analysis ===');

  try {
    final client = http.Client();
    final response = await client
        .get(
          Uri.parse('https://www.mamecha.com/online-shopping-1/'),
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

      // Look for Squarespace product grid
      final productGrid = document.querySelector('.ProductList-grid');
      if (productGrid != null) {
        final products = productGrid.querySelectorAll('.ProductList-item');
        print('✅ Squarespace ProductList found: ${products.length} products');

        if (products.isNotEmpty) {
          final firstProduct = products[0];

          // Check for title
          final titleEl = firstProduct.querySelector('.ProductList-title');
          if (titleEl != null) {
            print('   Title: "${titleEl.text.trim()}"');
          }

          // Check for price
          final priceEl = firstProduct.querySelector('.ProductList-price');
          if (priceEl != null) {
            print('   Price: "${priceEl.text.trim()}"');
          }

          // Check for link
          final linkEl = firstProduct.querySelector('a');
          if (linkEl != null) {
            print('   Link: "${linkEl.attributes['href']}"');
          }
        }
      } else {
        print('No Squarespace ProductList-grid found');

        // Check for other Squarespace patterns
        final squarespaceProducts = document.querySelectorAll(
          '.sqs-block-product',
        );
        if (squarespaceProducts.isNotEmpty) {
          print(
            'Found ${squarespaceProducts.length} sqs-block-product elements',
          );
        }

        // Check for summary blocks which might contain products
        final summaryBlocks = document.querySelectorAll(
          '.sqs-block-summary-v2',
        );
        if (summaryBlocks.isNotEmpty) {
          print('Found ${summaryBlocks.length} summary blocks');

          for (var block in summaryBlocks) {
            final items = block.querySelectorAll('.summary-item');
            if (items.isNotEmpty) {
              print('  Summary block with ${items.length} items');

              // Check first item
              if (items.isNotEmpty) {
                final firstItem = items[0];
                final titleEl = firstItem.querySelector('.summary-title a');
                if (titleEl != null) {
                  print('    Sample title: "${titleEl.text.trim()}"');
                }
              }
            }
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
  await analyzeMamechaDetails();
}
