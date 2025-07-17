import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

Future<void> testSite(
  String name,
  String url,
  String productSelector,
  String nameSelector,
) async {
  print('\n=== Testing $name ===');
  print('URL: $url');
  print('Product Selector: $productSelector');
  print('Name Selector: $nameSelector');

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
      print('✅ HTTP ${response.statusCode} - Success');

      // Parse HTML
      final document = parse.parse(response.body);
      final productElements = document.querySelectorAll(productSelector);

      print('📦 Found ${productElements.length} product elements');

      if (productElements.isNotEmpty) {
        // Check first few products
        int count = productElements.length > 3 ? 3 : productElements.length;
        for (int i = 0; i < count; i++) {
          final element = productElements[i];
          final nameElement = element.querySelector(nameSelector);
          final name = nameElement?.text.trim() ?? 'No name found';
          print('  Product ${i + 1}: $name');
        }
      } else {
        print('❌ No products found with selector: $productSelector');

        // Try to see what's in the page
        print(
          '\nPage title: ${document.querySelector('title')?.text ?? 'No title'}',
        );

        // Look for common product-related elements
        final commonSelectors = [
          '.product',
          '.item',
          '.card',
          '[class*="product"]',
          '[class*="item"]',
          'h3',
          'h2',
          '.grid-item',
          '.collection-item',
        ];

        for (String selector in commonSelectors) {
          final elements = document.querySelectorAll(selector);
          if (elements.isNotEmpty) {
            print('Found ${elements.length} elements with selector: $selector');
          }
        }
      }
    } else {
      print('❌ HTTP ${response.statusCode} - Failed');
      if (response.statusCode == 403) {
        print('  This might be blocked by bot protection');
      } else if (response.statusCode == 404) {
        print('  URL not found');
      }
    }

    client.close();
  } catch (e) {
    print('💥 Error: $e');
  }
}

void main() async {
  // Test problematic sites

  // Sazen Tea (mentioned as showing no text)
  await testSite(
    'Sazen Tea',
    'https://www.sazentea.com/en/products/c21-matcha',
    '.product, .item',
    'a[href*="/products/"]',
  );

  // Yoshien
  await testSite(
    'Yoshi En',
    'https://www.yoshien.com/matcha/',
    '.product, .item, .product-item',
    'h3 a, .product-title a, .name a',
  );

  // Matcha Kāru
  await testSite(
    'Matcha Kāru',
    'https://matcha-karu.com/collections/matcha-tee',
    '.product-item, .card, .product',
    '.product-title, h3, .card-title',
  );

  // Sho-Cha
  await testSite(
    'Sho-Cha',
    'https://www.sho-cha.com/teeshop',
    '.product, .item, .product-item',
    '.product-title, h3, .name',
  );

  // Mamecha
  await testSite(
    'Mamecha',
    'https://www.mamecha.com/online-shopping-1/',
    '.product, .item, .product-item',
    '.product-title, h3, .name',
  );

  // Enjoyemeri
  await testSite(
    'Enjoyemeri',
    'https://www.enjoyemeri.com/collections/shop-all',
    '.product-item, .card, .product',
    '.product-title, .card-title, h3',
  );
}
