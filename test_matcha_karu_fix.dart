// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parse;

String cleanPrice(String rawPrice) {
  if (rawPrice.isEmpty) return rawPrice;

  String cleaned = rawPrice.trim();

  // For Matcha Kāru, handle German price formatting
  // Example: "AngebotspreisAb 19,00 €" -> "19,00 €"
  cleaned = cleaned.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

  // Remove German text prefixes
  cleaned = cleaned.replaceAll('Angebotspreis', '');
  cleaned = cleaned.replaceAll('Ab ', '');
  cleaned = cleaned.replaceAll('ab ', '');
  cleaned = cleaned.trim();

  // Extract price with Euro symbol
  final priceMatch = RegExp(r'(\d+[.,]\d+)\s*€').firstMatch(cleaned);
  if (priceMatch != null) {
    return '${priceMatch.group(1)}€';
  }

  // Fallback: just clean up the string
  if (cleaned == '00' || cleaned == '0' || cleaned.startsWith('00 ')) {
    return '';
  }

  return cleaned;
}

Future<void> testMatchaKaruFix() async {
  print('=== Testing Matcha Kāru Fix ===');

  try {
    final client = http.Client();
    final response = await client
        .get(
          Uri.parse('https://matcha-karu.com/collections/matcha-tee'),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final document = parse.parse(response.body);
      final products = document.querySelectorAll('.product-item');

      print('Found ${products.length} products');

      for (int i = 0; i < (products.length > 3 ? 3 : products.length); i++) {
        final product = products[i];

        // Test name extraction
        final nameEl =
            product.querySelector('.product-item-meta__title') ??
            product.querySelector('.product-item__info a');
        final name = nameEl?.text.trim() ?? 'No name found';

        // Test price extraction
        final priceEl =
            product.querySelector('.price:first-child') ??
            product.querySelector('.price');
        final rawPrice = priceEl?.text.trim() ?? 'No price found';
        final cleanedPrice = cleanPrice(rawPrice);

        // Test link extraction
        final linkEl =
            product.querySelector('.product-item-meta__title') ??
            product.querySelector('.product-item__info a');
        final href = linkEl?.attributes['href'] ?? 'No link found';

        print('\nProduct ${i + 1}:');
        print('  Name: "$name"');
        print('  Raw Price: "$rawPrice"');
        print('  Cleaned Price: "$cleanedPrice"');
        print('  Link: "$href"');
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
  await testMatchaKaruFix();
}
