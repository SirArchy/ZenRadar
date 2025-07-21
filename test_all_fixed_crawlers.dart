// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await testAllFixedCrawlers();
}

Future<void> testAllFixedCrawlers() async {
  print('=== Testing All Fixed Crawlers ===\n');

  final sites = [
    {
      'name': 'Matcha Kāru',
      'url': 'https://matcha-karu.com/collections/matcha-tee',
      'productSelector': '.product-item',
      'nameSelector': '.product-item-meta__title, .product-item__info a',
      'priceSelector': '.price:first-child',
    },
    {
      'name': 'Ippodo Tea',
      'url': 'https://global.ippodo-tea.co.jp/collections/matcha',
      'productSelector': '.m-product-card',
      'nameSelector': '.m-product-card__name',
      'priceSelector': '.m-product-card__price',
    },
    {
      'name': 'Yoshi En',
      'url': 'https://www.yoshien.com/matcha/matcha-tee/',
      'productSelector': '.cs-product-tile',
      'nameSelector': '.cs-product-tile__name, .cs-product-tile__name-link',
      'priceSelector': '.cs-product-tile__price',
    },
    {
      'name': 'Sazen Tea',
      'url': 'https://www.sazentea.com/en/products/c21-matcha',
      'productSelector': '.product',
      'nameSelector': '.product-name',
      'priceSelector': '.product-price',
    },
  ];

  final results = <String, Map<String, dynamic>>{};

  for (final site in sites) {
    print('=== Testing ${site['name']} ===');

    try {
      final response = await http.get(
        Uri.parse(site['url'] as String),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
        },
      );

      if (response.statusCode != 200) {
        print('❌ Failed to fetch page: ${response.statusCode}');
        results[site['name'] as String] = {
          'status': 'FAILED',
          'error': 'HTTP ${response.statusCode}',
        };
        continue;
      }

      final document = html_parser.parse(response.body);
      final productElements = document.querySelectorAll(
        site['productSelector'] as String,
      );

      print('Found ${productElements.length} product elements');

      int validProducts = 0;
      final sampleProducts = <String>[];

      for (int i = 0; i < productElements.length && i < 3; i++) {
        final product = productElements[i];

        // Test name extraction
        final nameElement = product.querySelector(
          site['nameSelector'] as String,
        );
        final productName = nameElement?.text.trim() ?? '';

        // Test price extraction
        final priceElement = product.querySelector(
          site['priceSelector'] as String,
        );
        final productPrice = priceElement?.text.trim() ?? '';

        // Debug logging for Ippodo
        if (site['name'] == 'Ippodo Tea') {
          print(
            '  Product ${i + 1}: name="$productName", price="$productPrice"',
          );
          print('  Name element: ${nameElement != null}');
          print('  Price element: ${priceElement != null}');
          print('  Price contains ¥: ${productPrice.contains('¥')}');
        }

        final hasName = productName.isNotEmpty;
        final hasPrice =
            productPrice.isNotEmpty &&
            (productPrice.contains('€') ||
                productPrice.contains('\$') ||
                productPrice.contains('¥') ||
                productPrice.contains('USD') ||
                productPrice.contains('EUR'));

        if (hasName && hasPrice) {
          validProducts++;
          sampleProducts.add('$productName - $productPrice');
        }
      }

      if (validProducts > 0) {
        print('✅ SUCCESS: Found $validProducts valid products');
        for (final sample in sampleProducts) {
          print('  • $sample');
        }
        results[site['name'] as String] = {
          'status': 'SUCCESS',
          'totalProducts': productElements.length,
          'validProducts': validProducts,
          'samples': sampleProducts,
        };
      } else {
        print('❌ FAILED: No valid products found');
        results[site['name'] as String] = {
          'status': 'FAILED',
          'totalProducts': productElements.length,
          'validProducts': 0,
        };
      }
    } catch (e) {
      print('❌ ERROR: $e');
      results[site['name'] as String] = {
        'status': 'ERROR',
        'error': e.toString(),
      };
    }

    print('');
  }

  // Summary
  print('=== FINAL SUMMARY ===');
  int successCount = 0;
  int totalSites = sites.length;

  for (final entry in results.entries) {
    final siteName = entry.key;
    final result = entry.value;
    final status = result['status'] as String;

    if (status == 'SUCCESS') {
      successCount++;
      print('✅ $siteName: ${result['validProducts']} products found');
    } else {
      print('❌ $siteName: ${result['error'] ?? 'Failed'}');
    }
  }

  print(
    '\n🎯 OVERALL RESULT: $successCount/$totalSites sites working correctly',
  );

  if (successCount == totalSites) {
    print(
      '🎉 All crawler fixes are successful! All sites are now working properly.',
    );
  } else {
    print('⚠️  Some sites still need attention.');
  }
}
