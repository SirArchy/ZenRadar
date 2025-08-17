import '../services/currency_converter_service.dart';
import '../services/currency_price_service.dart';

/// Service for converting product prices to preferred currency with proper formatting
class ProductPriceConverter {
  static final ProductPriceConverter _instance =
      ProductPriceConverter._internal();
  factory ProductPriceConverter() => _instance;
  ProductPriceConverter._internal();

  static ProductPriceConverter get instance => _instance;

  final CurrencyConverterService _currencyConverter =
      CurrencyConverterService();
  final CurrencyPriceService _priceService = CurrencyPriceService.instance;

  /// Convert a product price to the preferred currency with rounded decimals
  /// Returns formatted price string with currency symbol
  Future<String?> convertPrice({
    required String? rawPrice,
    required String? productCurrency,
    required String preferredCurrency,
    required String siteKey,
    double? priceValue,
  }) async {
    if (rawPrice == null || rawPrice.isEmpty) return null;

    try {
      // First, try to use the priceValue if available (more accurate)
      if (priceValue != null && productCurrency != null) {
        return await _convertFromNumericValue(
          priceValue,
          productCurrency,
          preferredCurrency,
        );
      }

      // Extract price information using CurrencyPriceService
      final priceInfo = _priceService.extractPrice(rawPrice, siteKey);

      if (!priceInfo.isValid) {
        // Try to parse price manually with better decimal separator handling
        final parsedPrice = _parsePrice(rawPrice);
        if (parsedPrice != null) {
          final convertedValue = await _currencyConverter.convert(
            productCurrency ?? 'EUR',
            preferredCurrency,
            parsedPrice,
          );

          if (convertedValue != null) {
            return _formatPrice(convertedValue, preferredCurrency);
          }
        }

        // Fallback to raw price if extraction and parsing fails
        return rawPrice;
      }

      // Convert from EUR (normalized) to preferred currency
      final convertedValue = await _currencyConverter.convert(
        'EUR', // CurrencyPriceService normalizes everything to EUR
        preferredCurrency,
        priceInfo.priceValue!,
      );

      if (convertedValue != null) {
        return _formatPrice(convertedValue, preferredCurrency);
      }

      // Fallback to original price if conversion fails
      return priceInfo.displayPrice;
    } catch (e) {
      // Return original price if any error occurs
      return rawPrice;
    }
  }

  /// Parse price from string handling different decimal separators
  double? _parsePrice(String priceText) {
    // Remove currency symbols and extra spaces
    String cleaned =
        priceText
            .replaceAll(RegExp(r'[€\$£¥]|EUR|USD|GBP|JPY|CHF|CAD|AUD'), '')
            .trim();

    // Handle different decimal separator formats
    // European format: 24,50 or 1.234,50
    // American format: 24.50 or 1,234.50

    if (cleaned.contains(',') && cleaned.contains('.')) {
      // Both separators present - determine which is decimal
      final lastComma = cleaned.lastIndexOf(',');
      final lastPeriod = cleaned.lastIndexOf('.');

      if (lastComma > lastPeriod) {
        // European format: 1.234,50
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // American format: 1,234.50
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains(',')) {
      // Only comma - could be decimal or thousands separator
      final parts = cleaned.split(',');
      if (parts.length == 2 && parts[1].length <= 2) {
        // Likely decimal separator: 24,50
        cleaned = cleaned.replaceAll(',', '.');
      } else {
        // Likely thousands separator: 1,234
        cleaned = cleaned.replaceAll(',', '');
      }
    }
    // If only period, assume it's already in correct format

    // Extract just the number
    final match = RegExp(r'(\d+(?:\.\d{1,2})?)').firstMatch(cleaned);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }

    return null;
  }

  /// Convert from a numeric price value with known currency
  Future<String?> _convertFromNumericValue(
    double priceValue,
    String fromCurrency,
    String toCurrency,
  ) async {
    if (fromCurrency == toCurrency) {
      return _formatPrice(priceValue, toCurrency);
    }

    final convertedValue = await _currencyConverter.convert(
      fromCurrency,
      toCurrency,
      priceValue,
    );

    if (convertedValue != null) {
      return _formatPrice(convertedValue, toCurrency);
    }

    return null;
  }

  /// Format price with currency symbol and 2 decimal places
  String _formatPrice(double value, String currency) {
    final rounded = double.parse(value.toStringAsFixed(2));

    switch (currency) {
      case 'EUR':
        // European format with comma as decimal separator
        return '€${rounded.toStringAsFixed(2).replaceAll('.', ',')}';
      case 'USD':
      case 'GBP':
      case 'CHF':
      case 'CAD':
      case 'AUD':
        // American/British format with period as decimal separator
        final symbol = getCurrencySymbol(currency);
        if (currency == 'CHF' || currency == 'CAD' || currency == 'AUD') {
          return '$symbol ${rounded.toStringAsFixed(2)}';
        } else {
          return '$symbol${rounded.toStringAsFixed(2)}';
        }
      case 'JPY':
        return '¥${rounded.round()}'; // Yen doesn't use decimals
      default:
        return '${rounded.toStringAsFixed(2)} $currency';
    }
  }

  /// Get currency symbol for a given currency code
  String getCurrencySymbol(String currency) {
    switch (currency) {
      case 'EUR':
        return '€';
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'CHF':
        return 'CHF';
      case 'CAD':
        return 'CAD';
      case 'AUD':
        return 'AUD';
      default:
        return currency;
    }
  }
}
