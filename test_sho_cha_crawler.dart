// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  print('Testing Sho-cha crawler with price value calculation...\n');

  try {
    final response = await http.get(
      Uri.parse('https://www.sho-cha.com/teeshop'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      },
    );

    if (response.statusCode == 200) {
      final document = parser.parse(response.body);
      final productElements = document.querySelectorAll('.ProductList-item');

      print('Found ${productElements.length} products from Sho-cha');
      print('\nFirst 10 products with price values:');

      int count = 0;
      int nullPriceValues = 0;
      int validPriceValues = 0;

      for (final element in productElements) {
        if (count >= 10) break;

        final nameElement = element.querySelector(
          '.ProductList-title a, .ProductList-title',
        );
        final priceElement = element.querySelector('.product-price');

        if (nameElement != null && priceElement != null) {
          final name = nameElement.text.trim();
          final rawPrice = priceElement.text.trim();

          // Apply the same price cleaning logic as in crawler_service.dart
          String cleanedPrice = _cleanPrice(rawPrice, 'sho-cha');

          // Test price value extraction
          final priceValue = _extractPriceValue(cleanedPrice);

          print('${count + 1}. $name');
          print('   Raw price: "$rawPrice"');
          print('   Cleaned price: "$cleanedPrice"');
          print('   Price value: $priceValue');
          print('   Status: ${priceValue != null ? "✅ Valid" : "❌ Null"}');
          print('');

          if (priceValue != null) {
            validPriceValues++;
          } else {
            nullPriceValues++;
          }

          count++;
        }
      }

      print('Summary:');
      print('✅ Valid price values: $validPriceValues');
      print('❌ Null price values: $nullPriceValues');

      if (nullPriceValues == 0) {
        print('\n🎉 SUCCESS: All products have valid price values!');
        print('The "00" price issue should now be fixed.');
      } else {
        print('\n⚠️ WARNING: Some products still have null price values.');
      }
    } else {
      print('Failed to fetch website: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
  }
}

String _cleanPrice(String rawPrice, String siteName) {
  String cleaned = rawPrice;

  switch (siteName.toLowerCase()) {
    case 'sho-cha':
      // For Sho-Cha, handle German Euro formatting
      cleaned =
          cleaned
              .replaceAll('\u00A0', ' ') // Replace non-breaking space
              .replaceAll('\n', ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();

      // Extract price in German format (XX,XX €)
      final priceMatch = RegExp(r'(\d+(?:,\d{2})?\s*€)').firstMatch(cleaned);
      if (priceMatch != null) {
        return priceMatch.group(1)!.trim();
      }

      // Fallback: if it looks like a valid price, keep it
      if (cleaned.contains('€') && !cleaned.contains('00,00')) {
        return cleaned;
      }

      return ''; // Invalid price
  }

  return cleaned.trim();
}

/// Extract numeric price value from price string for filtering and comparison
double? _extractPriceValue(String? priceString) {
  if (priceString == null || priceString.isEmpty) return null;

  // Remove currency symbols and common text
  String cleaned =
      priceString
          .replaceAll('€', '')
          .replaceAll('\$', '')
          .replaceAll('£', '')
          .replaceAll('¥', '')
          .replaceAll('円', '')
          .replaceAll('CHF', '')
          .replaceAll('USD', '')
          .replaceAll('EUR', '')
          .replaceAll('JPY', '')
          .replaceAll('GBP', '')
          .replaceAll('CAD', '')
          .replaceAll('AUD', '')
          .replaceAll('Ab ', '')
          .replaceAll('ab ', '')
          .replaceAll('From ', '')
          .replaceAll('from ', '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  // Extract the first number with decimal places
  final priceMatch = RegExp(r'(\d+)[.,](\d+)').firstMatch(cleaned);
  if (priceMatch != null) {
    final wholePart = priceMatch.group(1)!;
    final decimalPart = priceMatch.group(2)!;
    return double.tryParse('$wholePart.$decimalPart');
  }

  // Try extracting integer prices
  final intMatch = RegExp(r'(\d+)').firstMatch(cleaned);
  if (intMatch != null) {
    return double.tryParse(intMatch.group(1)!);
  }

  return null;
}
