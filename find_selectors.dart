import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

Future<void> findCorrectSelectors(String name, String url) async {
  print('\n=== Finding Correct Selectors for $name ===');

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

      // Check for Squarespace (Sho-Cha)
      if (name == 'Sho-Cha') {
        print('🔍 Squarespace detected - looking for product grid...');
        final productGrid = document.querySelector('.ProductList-grid');
        if (productGrid != null) {
          final products = productGrid.querySelectorAll('.ProductList-item');
          print('Found ${products.length} products in ProductList-grid');

          for (
            int i = 0;
            i < (products.length > 3 ? 3 : products.length);
            i++
          ) {
            final product = products[i];
            final nameEl = product.querySelector(
              '.ProductList-title a, .ProductList-title',
            );
            final priceEl = product.querySelector('.ProductList-price');
            final addToCartEl = product.querySelector(
              '.AddToCartForm, .add-to-cart-button',
            );

            if (nameEl != null) {
              print('  Product ${i + 1}: "${nameEl.text.trim()}"');
              print('    Price: ${priceEl?.text.trim() ?? "Not found"}');
              print(
                '    Add to cart: ${addToCartEl != null ? "Found" : "Not found"}',
              );
            }
          }
        }
      }

      // Check for WooCommerce (Yoshien, others)
      if (name == 'Yoshien') {
        print('🔍 Looking for WordPress/custom structure...');

        // Check common product containers
        final selectors = [
          '.shop_table tbody tr',
          '.product-grid .product',
          '.products .product',
          '.woocommerce-LoopProduct-link',
          '.matcha-product',
          'table tbody tr',
          '.product-item',
        ];

        for (String selector in selectors) {
          final elements = document.querySelectorAll(selector);
          if (elements.isNotEmpty) {
            print('Found ${elements.length} products with: $selector');

            // Check first few for content
            for (
              int i = 0;
              i < (elements.length > 2 ? 2 : elements.length);
              i++
            ) {
              final element = elements[i];
              final text = element.text.trim();
              if (text.isNotEmpty && text.length < 200) {
                print(
                  '  Sample content: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."',
                );
              }

              // Look for links and product names
              final links = element.querySelectorAll('a');
              for (final link in links) {
                final href = link.attributes['href'];
                final linkText = link.text.trim();
                if (href != null &&
                    href.contains('matcha') &&
                    linkText.isNotEmpty) {
                  print('  Product link: "$linkText" -> $href');
                  break;
                }
              }
            }
            if (elements.isNotEmpty)
              break; // Found products, no need to check other selectors
          }
        }
      }

      // Check for specific e-commerce patterns
      if (name == 'Sazen Tea') {
        print('🔍 Looking for Sazen Tea structure...');

        // Check for common Zen Cart / custom patterns
        final selectors = [
          '.product-listing td',
          '.productListing-data',
          '.categoryListingTemplate',
          '.product-item',
          '.product-container',
          'table .productListing-data',
        ];

        for (String selector in selectors) {
          final elements = document.querySelectorAll(selector);
          if (elements.isNotEmpty) {
            print(
              'Found ${elements.length} potential products with: $selector',
            );

            for (
              int i = 0;
              i < (elements.length > 2 ? 2 : elements.length);
              i++
            ) {
              final element = elements[i];

              // Look for product names in links
              final productLinks = element.querySelectorAll(
                'a[href*="product"]',
              );
              for (final link in productLinks) {
                final linkText = link.text.trim();
                if (linkText.isNotEmpty && linkText.length > 3) {
                  print('  Product: "$linkText"');

                  // Look for price nearby
                  final parent = link.parent;
                  if (parent != null) {
                    final priceText = parent.text;
                    final priceMatch = RegExp(
                      r'[\$€£¥]\s*\d+[.,]\d+',
                    ).firstMatch(priceText);
                    if (priceMatch != null) {
                      print('    Price: ${priceMatch.group(0)}');
                    }
                  }
                  break;
                }
              }
            }
            if (elements.isNotEmpty) break;
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
  await findCorrectSelectors('Sho-Cha', 'https://www.sho-cha.com/teeshop');
  await findCorrectSelectors('Yoshien', 'https://www.yoshien.com/matcha/');
  await findCorrectSelectors(
    'Sazen Tea',
    'https://www.sazentea.com/en/products/c21-matcha',
  );
}
