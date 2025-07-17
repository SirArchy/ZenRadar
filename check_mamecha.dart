// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

Future<void> checkMamecha() async {
  print('\n=== Analyzing Mamecha ===');

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

      // Check for Squarespace patterns (like Sho-Cha)
      final squarespaceSelectors = [
        '.ProductList-item',
        '.grid-item',
        '.sqs-block-product',
      ];

      for (String selector in squarespaceSelectors) {
        final products = document.querySelectorAll(selector);
        if (products.isNotEmpty) {
          print('✅ Found ${products.length} products with: $selector');

          if (products.isNotEmpty) {
            final firstProduct = products[0];
            print('Sample HTML structure:');
            print('${firstProduct.outerHtml.substring(0, 300)}...');
          }
          break;
        }
      }

      // Also check for general e-commerce patterns
      final generalSelectors = [
        '.product',
        '.item',
        '[class*="product"]',
        '.shop-item',
        'article',
      ];

      for (String selector in generalSelectors) {
        final products = document.querySelectorAll(selector);
        if (products.isNotEmpty && products.length > 3) {
          print('Found ${products.length} potential products with: $selector');
          break;
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
  await checkMamecha();
}
