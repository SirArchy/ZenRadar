// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

Future<void> analyzePageStructure(String name, String url) async {
  print('\n=== Analyzing $name ===');
  print('URL: $url');

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

      // Look for elements with product-related class names
      final productClassSelectors = [
        '[class*="product"]',
        '[class*="item"]',
        '[class*="card"]',
        '[class*="grid"]',
      ];

      for (String selector in productClassSelectors) {
        final elements = document.querySelectorAll(selector);
        if (elements.isNotEmpty && elements.length < 50) {
          // Avoid too many results
          print('\n🔍 Found ${elements.length} elements with $selector:');
          for (
            int i = 0;
            i < (elements.length > 5 ? 5 : elements.length);
            i++
          ) {
            final element = elements[i];
            final classes = element.attributes['class'] ?? '';
            print('  Element ${i + 1}: class="$classes"');

            // Look for text content in common name selectors
            final nameSelectors = [
              'h1',
              'h2',
              'h3',
              'h4',
              'a',
              '.title',
              '[class*="title"]',
              '[class*="name"]',
            ];
            for (String nameSelector in nameSelectors) {
              final nameEl = element.querySelector(nameSelector);
              if (nameEl != null && nameEl.text.trim().isNotEmpty) {
                final text = nameEl.text.trim();
                if (text.length > 3 && text.length < 100) {
                  // Reasonable product name length
                  print('    Found text in $nameSelector: "$text"');
                  break; // Found a good name, move to next element
                }
              }
            }
          }
        }
      }

      // Also check for specific e-commerce platform patterns
      print('\n🛒 E-commerce platform detection:');
      if (document.querySelector('[data-shopify]') != null) {
        print('  Detected: Shopify');
        // Check Shopify-specific selectors
        final shopifyProducts = document.querySelectorAll(
          '.product-item, .grid-product__content, .product-card',
        );
        print('  Shopify products found: ${shopifyProducts.length}');
      }

      if (document.querySelector('[class*="woocommerce"]') != null ||
          document.querySelector('[class*="woo-"]') != null) {
        print('  Detected: WooCommerce');
        final wooProducts = document.querySelectorAll(
          '.product, .woocommerce-LoopProduct-link',
        );
        print('  WooCommerce products found: ${wooProducts.length}');
      }

      if (document.querySelector('[class*="magento"]') != null) {
        print('  Detected: Magento');
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
  // Focus on the most problematic sites first
  await analyzePageStructure(
    'Sazen Tea',
    'https://www.sazentea.com/en/products/c21-matcha',
  );
  await analyzePageStructure('Sho-Cha', 'https://www.sho-cha.com/teeshop');
  await analyzePageStructure('Yoshien', 'https://www.yoshien.com/matcha/');
}
