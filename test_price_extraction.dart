/// Test script to verify the new CurrencyPriceService integration
library;
// ignore_for_file: avoid_print

import 'lib/services/currency_price_service.dart';

void main() {
  final priceService = CurrencyPriceService.instance;

  print('Testing CurrencyPriceService with problematic price formats:\n');

  // Test Tokichi duplicate price issue
  print('=== TOKICHI TESTS ===');
  final tokichiDuplicate = '€28,00€28,00';
  final tokichiResult = priceService.extractPrice(tokichiDuplicate, 'tokichi');
  print('Input: "$tokichiDuplicate"');
  print('Display Price: "${tokichiResult.displayPrice}"');
  print('Price Value: ${tokichiResult.priceValue}');
  print('Valid: ${tokichiResult.isValid}\n');

  // Test Marukyu multi-currency issue
  print('=== MARUKYU TESTS ===');
  final marukyu1 = '4209.61€8.26£7.15¥68.39';
  final marukyu1Result = priceService.extractPrice(marukyu1, 'marukyu');
  print('Input: "$marukyu1"');
  print('Display Price: "${marukyu1Result.displayPrice}"');
  print('Price Value: ${marukyu1Result.priceValue}');
  print('Valid: ${marukyu1Result.isValid}\n');

  final marukyu2 = '100~14.21~€12.21~';
  final marukyu2Result = priceService.extractPrice(marukyu2, 'marukyu');
  print('Input: "$marukyu2"');
  print('Display Price: "${marukyu2Result.displayPrice}"');
  print('Price Value: ${marukyu2Result.priceValue}');
  print('Valid: ${marukyu2Result.isValid}\n');

  // Test Ippodo yen conversion
  print('=== IPPODO TESTS ===');
  final ippodo1 = '¥3,888';
  final ippodo1Result = priceService.extractPrice(ippodo1, 'ippodo');
  print('Input: "$ippodo1"');
  print('Display Price: "${ippodo1Result.displayPrice}"');
  print('Price Value: ${ippodo1Result.priceValue}');
  print('Valid: ${ippodo1Result.isValid}\n');

  final ippodo2 = '3,888円';
  final ippodo2Result = priceService.extractPrice(ippodo2, 'ippodo');
  print('Input: "$ippodo2"');
  print('Display Price: "${ippodo2Result.displayPrice}"');
  print('Price Value: ${ippodo2Result.priceValue}');
  print('Valid: ${ippodo2Result.isValid}\n');

  // Test other sites for consistency
  print('=== OTHER SITES TESTS ===');
  final sho1 = 'Angebotspreis24,00 €';
  final sho1Result = priceService.extractPrice(sho1, 'sho-cha');
  print('Sho-Cha Input: "$sho1"');
  print('Display Price: "${sho1Result.displayPrice}"');
  print('Price Value: ${sho1Result.priceValue}\n');

  final karu1 = 'AngebotspreisAb 19,00 €';
  final karu1Result = priceService.extractPrice(karu1, 'matcha-karu');
  print('Matcha-Karu Input: "$karu1"');
  print('Display Price: "${karu1Result.displayPrice}"');
  print('Price Value: ${karu1Result.priceValue}\n');
}
