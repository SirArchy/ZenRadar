import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

// Test the updated selectors
Future<void> testUpdatedSelectors() async {
  final testConfigs = [
    {
      'name': 'Sho-Cha',
      'url': 'https://www.sho-cha.com/teeshop',
      'productSelector': '.ProductList-item',
      'nameSelector': '.ProductList-title a, .ProductList-title',
      'priceSelector':
          '.ProductList-price .sqs-money-native, .ProductList-price',
    },
    {
      'name': 'Matcha Kāru',
      'url': 'https://matcha-karu.com/collections/matcha-tee',
      'productSelector': '.product-item',
      'nameSelector': '.product-title, h3',
      'priceSelector': '.price',
    },
    {
      'name': 'Enjoyemeri',
      'url': 'https://www.enjoyemeri.com/collections/shop-all',
      'productSelector': '.product-card',
      'nameSelector': 'h3',
      'priceSelector': '.price',
    },
  ];

  for (var config in testConfigs) {
    print('\n=== Testing ${config['name']} ===');

    try {
      final client = http.Client();
      final response = await client
          .get(
            Uri.parse(config['url']!),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final document = parse.parse(response.body);
        final products = document.querySelectorAll(config['productSelector']!);

        print('✅ Found ${products.length} products');

        if (products.isNotEmpty) {
          // Test first product
          final product = products[0];

          final nameSelectors = config['nameSelector']!.split(', ');
          String? productName;

          for (String selector in nameSelectors) {
            final nameEl = product.querySelector(selector.trim());
            if (nameEl != null && nameEl.text.trim().isNotEmpty) {
              productName = nameEl.text.trim();
              break;
            }
          }

          final priceSelectors = config['priceSelector']!.split(', ');
          String? productPrice;

          for (String selector in priceSelectors) {
            final priceEl = product.querySelector(selector.trim());
            if (priceEl != null && priceEl.text.trim().isNotEmpty) {
              productPrice = priceEl.text.trim();
              break;
            }
          }

          print('   Sample Product: "${productName ?? "Name not found"}"');
          print('   Price: "${productPrice ?? "Price not found"}"');

          if (productName != null && productName.isNotEmpty) {
            print('   ✅ Name extraction working');
          } else {
            print('   ❌ Name extraction failed');
          }

          if (productPrice != null && productPrice.isNotEmpty) {
            print('   ✅ Price extraction working');
          } else {
            print('   ❌ Price extraction failed');
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
  await testUpdatedSelectors();
}
