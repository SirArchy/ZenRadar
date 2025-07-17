import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

Future<void> checkShopifySites() async {
  final sites = [
    {
      'name': 'Matcha Kāru',
      'url': 'https://matcha-karu.com/collections/matcha-tee',
    },
    {
      'name': 'Enjoyemeri',
      'url': 'https://www.enjoyemeri.com/collections/shop-all',
    },
  ];

  for (var site in sites) {
    print('\n=== Analyzing ${site['name']} ===');

    try {
      final client = http.Client();
      final response = await client
          .get(
            Uri.parse(site['url']!),
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

        // Check for Shopify patterns
        final shopifySelectors = [
          '.grid__item',
          '.product-item',
          '.product-card',
          '.card-wrapper',
          '.product-grid-item',
          '[data-product-id]',
        ];

        for (String selector in shopifySelectors) {
          final products = document.querySelectorAll(selector);
          if (products.isNotEmpty && products.length > 5) {
            print('✅ Found ${products.length} products with: $selector');

            // Analyze first product
            final firstProduct = products[0];

            // Look for product name
            final nameSelectors = [
              '.card__heading a',
              '.product-title',
              '.card-title',
              'h3 a',
              'h3',
              '.product-name',
            ];

            for (String nameSelector in nameSelectors) {
              final nameEl = firstProduct.querySelector(nameSelector);
              if (nameEl != null && nameEl.text.trim().isNotEmpty) {
                print('   Name selector: $nameSelector');
                print('   Sample: "${nameEl.text.trim()}"');
                break;
              }
            }

            // Look for price
            final priceSelectors = [
              '.price',
              '.money',
              '.price__current',
              '.product-price',
              '.card__price',
            ];

            for (String priceSelector in priceSelectors) {
              final priceEl = firstProduct.querySelector(priceSelector);
              if (priceEl != null && priceEl.text.trim().isNotEmpty) {
                print('   Price selector: $priceSelector');
                print('   Sample: "${priceEl.text.trim()}"');
                break;
              }
            }

            // Look for links
            final linkSelectors = ['a', '.card__heading a', '.product-link'];

            for (String linkSelector in linkSelectors) {
              final linkEl = firstProduct.querySelector(linkSelector);
              if (linkEl != null && linkEl.attributes['href'] != null) {
                print('   Link selector: $linkSelector');
                print('   Sample href: "${linkEl.attributes['href']}"');
                break;
              }
            }

            break; // Found products, no need to check other selectors
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
}

void main() async {
  await checkShopifySites();
}
