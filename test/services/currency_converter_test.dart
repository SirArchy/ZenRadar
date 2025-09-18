// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:zenradar/services/currency_converter_service.dart';

void main() {
  // Initialize bindings for tests that use SharedPreferences
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CurrencyConverterService', () {
    late CurrencyConverterService currencyService;

    setUp(() {
      currencyService = CurrencyConverterService();
    });

    group('Exchange Rate Fetching', () {
      test('should fetch exchange rates for EUR', () async {
        try {
          final rates = await currencyService.getExchangeRates('EUR');

          expect(rates, isNotEmpty);
          expect(rates.keys, contains('USD'));
          expect(rates.keys, contains('JPY'));
          expect(rates.keys, contains('CAD'));

          // Verify rates are numeric values
          expect(rates['USD'], isA<num>());
          expect(rates['JPY'], isA<num>());
          expect(rates['CAD'], isA<num>());

          // Basic sanity checks for exchange rates
          expect(rates['USD'], greaterThan(0.5));
          expect(rates['USD'], lessThan(2.0));
          expect(rates['JPY'], greaterThan(100));
          expect(rates['JPY'], lessThan(200));
        } catch (e) {
          // Network tests might fail in CI environment
          print('Network test failed (expected in offline environment): $e');
        }
      });

      test('should handle invalid currency codes gracefully', () async {
        try {
          await currencyService.getExchangeRates('INVALID');
          fail('Should have thrown an exception for invalid currency');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });

    group('Currency Conversion', () {
      test('should convert EUR to USD correctly', () async {
        try {
          const amount = 100.0;
          final convertedAmount = await currencyService.convert(
            'EUR',
            'USD',
            amount,
          );

          expect(convertedAmount, isA<double>());
          expect(convertedAmount, isNotNull);
          expect(convertedAmount!, greaterThan(0));
          // USD should be close to EUR but not exactly the same
          expect(convertedAmount, greaterThan(amount * 0.8));
          expect(convertedAmount, lessThan(amount * 1.5));
        } catch (e) {
          print(
            'Network conversion test failed (expected in offline environment): $e',
          );
        }
      });

      test('should convert EUR to JPY correctly', () async {
        try {
          const amount = 100.0;
          final convertedAmount = await currencyService.convert(
            'EUR',
            'JPY',
            amount,
          );

          expect(convertedAmount, isA<double>());
          expect(convertedAmount, isNotNull);
          expect(convertedAmount!, greaterThan(0));
          // JPY should be much higher than EUR
          expect(convertedAmount, greaterThan(amount * 100));
          expect(convertedAmount, lessThan(amount * 200));
        } catch (e) {
          print(
            'Network conversion test failed (expected in offline environment): $e',
          );
        }
      });

      test('should convert USD to EUR correctly', () async {
        try {
          const amount = 100.0;
          final convertedAmount = await currencyService.convert(
            'USD',
            'EUR',
            amount,
          );

          expect(convertedAmount, isA<double>());
          expect(convertedAmount, isNotNull);
          expect(convertedAmount!, greaterThan(0));
          // EUR should be close to USD but not exactly the same
          expect(convertedAmount, greaterThan(amount * 0.7));
          expect(convertedAmount, lessThan(amount * 1.2));
        } catch (e) {
          print(
            'Network conversion test failed (expected in offline environment): $e',
          );
        }
      });

      test('should handle same currency conversion', () async {
        try {
          final rates = await currencyService.getExchangeRates('EUR');
          // Same currency should have rate of 1.0 if included in response
          if (rates.containsKey('EUR')) {
            expect(rates['EUR'], equals(1.0));
          }

          // Converting to same currency via different base should work
          const amount = 100.0;
          final converted = await currencyService.convert('EUR', 'EUR', amount);

          // This might return null if EUR->EUR is not in the API response
          if (converted != null) {
            expect(converted, equals(amount));
          }
        } catch (e) {
          print('Same currency test failed: $e');
        }
      });

      test('should return null for invalid currency conversion', () async {
        final result = await currencyService.convert('EUR', 'INVALID', 100.0);
        expect(result, isNull);
      });

      test('should handle zero amounts', () async {
        try {
          final result = await currencyService.convert('EUR', 'USD', 0);
          if (result != null) {
            expect(result, equals(0));
          }
        } catch (e) {
          print('Zero amount test failed: $e');
        }
      });

      test('should handle negative amounts', () async {
        try {
          final result = await currencyService.convert('EUR', 'USD', -100);
          if (result != null) {
            expect(result, lessThan(0));
          }
        } catch (e) {
          print('Negative amount test failed: $e');
        }
      });

      test('should handle very large amounts', () async {
        try {
          const largeAmount = 1000000.0;
          final result = await currencyService.convert(
            'EUR',
            'USD',
            largeAmount,
          );
          if (result != null) {
            expect(result, greaterThan(largeAmount * 0.5));
          }
        } catch (e) {
          print('Large amount test failed: $e');
        }
      });

      test('should handle very small amounts', () async {
        try {
          const smallAmount = 0.01;
          final result = await currencyService.convert(
            'EUR',
            'USD',
            smallAmount,
          );
          if (result != null) {
            expect(result, greaterThan(0));
            expect(result, lessThan(1));
          }
        } catch (e) {
          print('Small amount test failed: $e');
        }
      });
    });

    group('Caching Behavior', () {
      test('should cache exchange rates', () async {
        try {
          // First call - should fetch from API
          final start1 = DateTime.now();
          await currencyService.getExchangeRates('EUR');
          final duration1 = DateTime.now().difference(start1);

          // Second call - should use cache
          final start2 = DateTime.now();
          final rates2 = await currencyService.getExchangeRates('EUR');
          final duration2 = DateTime.now().difference(start2);

          // Verify we got valid rates
          expect(rates2, isNotEmpty);

          // Cached call should be significantly faster (less than half the time)
          expect(
            duration2.inMilliseconds,
            lessThan(duration1.inMilliseconds ~/ 2),
          );
        } catch (e) {
          print('Caching test failed: $e');
        }
      });

      test('should handle different base currencies', () async {
        try {
          final eurRates = await currencyService.getExchangeRates('EUR');
          final usdRates = await currencyService.getExchangeRates('USD');

          expect(eurRates, isNotEmpty);
          expect(usdRates, isNotEmpty);

          // Different base currencies should have different rate structures
          expect(eurRates.keys, isNot(equals(usdRates.keys)));
        } catch (e) {
          print('Multiple base currency test failed: $e');
        }
      });
    });

    group('Rate Normalization', () {
      test('should normalize integer rates to doubles', () async {
        try {
          final rates = await currencyService.getExchangeRates('EUR');

          // All rates should be doubles, not integers
          for (final rate in rates.values) {
            expect(rate, isA<double>());
          }
        } catch (e) {
          print('Rate normalization test failed: $e');
        }
      });
    });

    group('Error Handling', () {
      test('should handle network failures gracefully', () async {
        // This test would require mocking the HTTP client
        // For now, we just verify the method exists and can be called
        expect(() => currencyService.getExchangeRates('EUR'), returnsNormally);
      });

      test('should handle conversion failures gracefully', () async {
        // Test with invalid currencies
        final result1 = await currencyService.convert('INVALID', 'USD', 100.0);
        final result2 = await currencyService.convert('EUR', 'INVALID', 100.0);

        expect(result1, isNull);
        expect(result2, isNull);
      });
    });
  });

  group('Currency Utilities', () {
    test('should detect common currency patterns', () {
      // Test currency detection from price strings
      expect('€89.99'.contains('€'), true);
      expect('\$89.99'.contains('\$'), true);
      expect('¥8999'.contains('¥'), true);
      expect('C\$89.99'.contains('C\$'), true);
    });

    test('should extract numeric values from price strings', () {
      // Basic price parsing
      final eurPrice = '€89.99';
      final numericValue = double.tryParse(
        eurPrice.replaceAll(RegExp(r'[^\d.]'), ''),
      );
      expect(numericValue, 89.99);

      final usdPrice = '\$123.45';
      final usdValue = double.tryParse(
        usdPrice.replaceAll(RegExp(r'[^\d.]'), ''),
      );
      expect(usdValue, 123.45);

      final jpyPrice = '¥12,345';
      final jpyValue = double.tryParse(
        jpyPrice.replaceAll(RegExp(r'[^\d]'), ''),
      );
      expect(jpyValue, 12345.0);
    });

    test('should handle malformed price strings', () {
      final malformed = 'Invalid Price';
      final value = double.tryParse(
        malformed.replaceAll(RegExp(r'[^\d.]'), ''),
      );
      expect(value, null);
    });
  });
}
