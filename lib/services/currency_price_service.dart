/// Service for handling currency conversion and price normalization
class CurrencyPriceService {
  static final CurrencyPriceService _instance =
      CurrencyPriceService._internal();
  factory CurrencyPriceService() => _instance;
  CurrencyPriceService._internal();

  static CurrencyPriceService get instance => _instance;

  // Approximate exchange rates - in production, you'd want to fetch these from an API
  static const Map<String, double> _exchangeRates = {
    'EUR': 1.0, // Base currency
    'USD': 0.92, // 1 USD = 0.92 EUR
    'GBP': 1.16, // 1 GBP = 1.16 EUR
    'JPY': 0.0067, // 1 JPY = 0.0067 EUR
  };

  /// Extract and normalize price information from raw price text
  PriceInfo extractPrice(String rawPrice, String siteKey) {
    if (rawPrice.isEmpty) {
      return PriceInfo(
        originalPrice: '',
        normalizedEuroPrice: null,
        currency: 'EUR',
        priceValue: null,
      );
    }

    String cleaned = rawPrice.trim();

    switch (siteKey) {
      case 'tokichi':
        return _extractTokichiPrice(cleaned);
      case 'marukyu':
        return _extractMarukyuPrice(cleaned);
      case 'ippodo':
        return _extractIppodoPrice(cleaned);
      case 'horrimeicha':
        return _extractHorrimichaPrice(cleaned);
      case 'sho-cha':
        return _extractShoChaPrice(cleaned);
      case 'matcha-karu':
        return _extractMatchaKaruPrice(cleaned);
      case 'poppatea':
        return _extractPoppateaPrice(cleaned);
      case 'yoshien':
        return _extractYoshienPrice(cleaned);
      case 'sazentea':
        return _extractSazenteaPrice(cleaned);
      default:
        return _extractGenericPrice(cleaned);
    }
  }

  /// Handle Tokichi price extraction (fixes duplicate price issue)
  PriceInfo _extractTokichiPrice(String cleaned) {
    // Fix duplicate price issue: €28,00€28,00 -> €28,00
    final duplicateMatch = RegExp(
      r'(€\d+[.,]\d+)€\d+[.,]\d+',
    ).firstMatch(cleaned);
    if (duplicateMatch != null) {
      cleaned = duplicateMatch.group(1)!;
    }

    // Extract Euro price
    final euroMatch = RegExp(r'€(\d+[.,]\d+)').firstMatch(cleaned);
    if (euroMatch != null) {
      final priceText = euroMatch.group(1)!.replaceAll(',', '.');
      final priceValue = double.tryParse(priceText);

      return PriceInfo(
        originalPrice: '€${euroMatch.group(1)}',
        normalizedEuroPrice: '€${euroMatch.group(1)}',
        currency: 'EUR',
        priceValue: priceValue,
      );
    }

    return PriceInfo(
      originalPrice: cleaned,
      normalizedEuroPrice: null,
      currency: 'EUR',
      priceValue: null,
    );
  }

  /// Handle Marukyu price extraction (always prioritize Euro)
  PriceInfo _extractMarukyuPrice(String cleaned) {
    // Handle multi-currency format: "4209.61€8.26£7.15¥68.39"
    final eurMatch = RegExp(r'€(\d+[.,]\d+)').firstMatch(cleaned);
    final usdMatch = RegExp(r'[\$](\d+[.,]\d+)').firstMatch(cleaned);
    final gbpMatch = RegExp(r'£(\d+[.,]\d+)').firstMatch(cleaned);
    final jpyMatch = RegExp(r'¥(\d+[.,]\d+)').firstMatch(cleaned);

    // Always prioritize Euro if available
    if (eurMatch != null) {
      final priceText = eurMatch.group(1)!.replaceAll(',', '.');
      final priceValue = double.tryParse(priceText);

      return PriceInfo(
        originalPrice: cleaned,
        normalizedEuroPrice: '€${eurMatch.group(1)}',
        currency: 'EUR',
        priceValue: priceValue,
      );
    }

    // Convert other currencies to Euro
    if (usdMatch != null) {
      final usdValue = double.tryParse(usdMatch.group(1)!.replaceAll(',', '.'));
      if (usdValue != null) {
        final euroValue = usdValue * _exchangeRates['USD']!;
        return PriceInfo(
          originalPrice: cleaned,
          normalizedEuroPrice: '€${euroValue.toStringAsFixed(2)}',
          currency: 'EUR',
          priceValue: euroValue,
        );
      }
    }

    if (gbpMatch != null) {
      final gbpValue = double.tryParse(gbpMatch.group(1)!.replaceAll(',', '.'));
      if (gbpValue != null) {
        final euroValue = gbpValue * _exchangeRates['GBP']!;
        return PriceInfo(
          originalPrice: cleaned,
          normalizedEuroPrice: '€${euroValue.toStringAsFixed(2)}',
          currency: 'EUR',
          priceValue: euroValue,
        );
      }
    }

    if (jpyMatch != null) {
      final jpyValue = double.tryParse(jpyMatch.group(1)!.replaceAll(',', '.'));
      if (jpyValue != null) {
        final euroValue = jpyValue * _exchangeRates['JPY']!;
        return PriceInfo(
          originalPrice: cleaned,
          normalizedEuroPrice: '€${euroValue.toStringAsFixed(2)}',
          currency: 'EUR',
          priceValue: euroValue,
        );
      }
    }

    // Handle tilde-separated format: "100~14.21~€12.21~"
    if (cleaned.contains('~')) {
      final parts =
          cleaned.split('~').where((p) => p.trim().isNotEmpty).toList();

      for (String part in parts) {
        part = part.trim();
        final euroMatch = RegExp(r'€(\d+[.,]\d+)').firstMatch(part);
        if (euroMatch != null) {
          final priceText = euroMatch.group(1)!.replaceAll(',', '.');
          final priceValue = double.tryParse(priceText);

          return PriceInfo(
            originalPrice: cleaned,
            normalizedEuroPrice: '€${euroMatch.group(1)}',
            currency: 'EUR',
            priceValue: priceValue,
          );
        }
      }
    }

    return PriceInfo(
      originalPrice: cleaned,
      normalizedEuroPrice: null,
      currency: 'EUR',
      priceValue: null,
    );
  }

  /// Handle Ippodo price extraction (convert Yen to Euro)
  PriceInfo _extractIppodoPrice(String cleaned) {
    // Extract Yen price
    final jpyMatch = RegExp(r'¥(\d+[.,]\d+)').firstMatch(cleaned);
    if (jpyMatch != null) {
      final jpyText = jpyMatch.group(1)!.replaceAll(',', '');
      final jpyValue = double.tryParse(jpyText);

      if (jpyValue != null) {
        final euroValue = jpyValue * _exchangeRates['JPY']!;

        return PriceInfo(
          originalPrice: '¥${jpyMatch.group(1)}',
          normalizedEuroPrice: '€${euroValue.toStringAsFixed(2)}',
          currency: 'EUR',
          priceValue: euroValue,
        );
      }
    }

    // Handle format without currency symbol (assume JPY)
    final numMatch = RegExp(r'(\d+[.,]\d+)').firstMatch(cleaned);
    if (numMatch != null) {
      final jpyValue = double.tryParse(numMatch.group(1)!.replaceAll(',', ''));

      if (jpyValue != null) {
        final euroValue = jpyValue * _exchangeRates['JPY']!;

        return PriceInfo(
          originalPrice: cleaned,
          normalizedEuroPrice: '€${euroValue.toStringAsFixed(2)}',
          currency: 'EUR',
          priceValue: euroValue,
        );
      }
    }

    return PriceInfo(
      originalPrice: cleaned,
      normalizedEuroPrice: null,
      currency: 'EUR',
      priceValue: null,
    );
  }

  /// Handle Horrimeicha price extraction
  PriceInfo _extractHorrimichaPrice(String cleaned) {
    // Try to extract Euro prices (common format: €XX.XX)
    final euroMatch = RegExp(r'€(\d+[.,]\d+)').firstMatch(cleaned);
    if (euroMatch != null) {
      final priceText = euroMatch.group(1)!.replaceAll(',', '.');
      final priceValue = double.tryParse(priceText);

      if (priceValue != null) {
        return PriceInfo(
          originalPrice: cleaned,
          normalizedEuroPrice: '€${priceValue.toStringAsFixed(2)}',
          currency: 'EUR',
          priceValue: priceValue,
        );
      }
    }

    // Try to extract USD prices and convert to EUR
    final usdMatch = RegExp(r'\$(\d+[.,]\d+)').firstMatch(cleaned);
    if (usdMatch != null) {
      final priceText = usdMatch.group(1)!.replaceAll(',', '.');
      final usdValue = double.tryParse(priceText);

      if (usdValue != null) {
        final euroValue = usdValue * _exchangeRates['USD']!;
        return PriceInfo(
          originalPrice: cleaned,
          normalizedEuroPrice: '€${euroValue.toStringAsFixed(2)}',
          currency: 'EUR',
          priceValue: euroValue,
        );
      }
    }

    return PriceInfo(
      originalPrice: cleaned,
      normalizedEuroPrice: null,
      currency: 'EUR',
      priceValue: null,
    );
  }

  /// Handle generic price extraction
  PriceInfo _extractGenericPrice(String cleaned) {
    // Try to extract Euro first
    final euroMatch = RegExp(r'€(\d+[.,]\d+)').firstMatch(cleaned);
    if (euroMatch != null) {
      final priceText = euroMatch.group(1)!.replaceAll(',', '.');
      final priceValue = double.tryParse(priceText);

      return PriceInfo(
        originalPrice: cleaned,
        normalizedEuroPrice: '€${euroMatch.group(1)}',
        currency: 'EUR',
        priceValue: priceValue,
      );
    }

    // Try other currencies and convert
    final usdMatch = RegExp(r'[\$](\d+[.,]\d+)').firstMatch(cleaned);
    if (usdMatch != null) {
      final usdValue = double.tryParse(usdMatch.group(1)!.replaceAll(',', '.'));
      if (usdValue != null) {
        final euroValue = usdValue * _exchangeRates['USD']!;
        return PriceInfo(
          originalPrice: cleaned,
          normalizedEuroPrice: '€${euroValue.toStringAsFixed(2)}',
          currency: 'EUR',
          priceValue: euroValue,
        );
      }
    }

    return PriceInfo(
      originalPrice: cleaned,
      normalizedEuroPrice: null,
      currency: 'EUR',
      priceValue: null,
    );
  }

  /// Handle Sho-Cha price extraction
  PriceInfo _extractShoChaPrice(String cleaned) {
    // Clean up the text
    cleaned =
        cleaned
            .replaceAll('\u00A0', ' ') // Replace non-breaking space
            .replaceAll('\n', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll('Angebotspreis', '')
            .trim();

    // Extract price in German format (XX,XX €)
    final euroPriceMatch = RegExp(r'(\d+(?:,\d{2})?)\s*€').firstMatch(cleaned);
    if (euroPriceMatch != null) {
      final priceText = euroPriceMatch.group(1)!.replaceAll(',', '.');
      final priceValue = double.tryParse(priceText);
      if (priceValue != null && priceValue > 0) {
        return PriceInfo(
          originalPrice: cleaned,
          normalizedEuroPrice: '€${priceText.replaceAll('.', ',')}',
          currency: 'EUR',
          priceValue: priceValue,
        );
      }
    }

    // Try USD format and convert
    final usdPriceMatch = RegExp(r'\$(\d+(?:\.\d{2})?)').firstMatch(cleaned);
    if (usdPriceMatch != null) {
      final usdValue = double.tryParse(usdPriceMatch.group(1)!);
      if (usdValue != null && usdValue > 0) {
        final euroValue = usdValue * _exchangeRates['USD']!;
        return PriceInfo(
          originalPrice: cleaned,
          normalizedEuroPrice:
              '€${euroValue.toStringAsFixed(2).replaceAll('.', ',')}',
          currency: 'EUR',
          priceValue: euroValue,
        );
      }
    }

    return PriceInfo(
      originalPrice: cleaned,
      normalizedEuroPrice: null,
      currency: 'EUR',
      priceValue: null,
    );
  }

  /// Handle Matcha-Karu price extraction
  PriceInfo _extractMatchaKaruPrice(String cleaned) {
    // Clean up the text
    cleaned = cleaned.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

    // Remove German text prefixes
    cleaned =
        cleaned
            .replaceAll('Angebotspreis', '')
            .replaceAll('Ab ', '')
            .replaceAll('ab ', '')
            .trim();

    // Extract price with Euro symbol
    final priceMatch = RegExp(r'(\d+[.,]\d+)\s*€').firstMatch(cleaned);
    if (priceMatch != null) {
      final priceText = priceMatch.group(1)!.replaceAll(',', '.');
      final priceValue = double.tryParse(priceText);
      if (priceValue != null && priceValue > 0) {
        return PriceInfo(
          originalPrice: cleaned,
          normalizedEuroPrice: '€${priceText.replaceAll('.', ',')}',
          currency: 'EUR',
          priceValue: priceValue,
        );
      }
    }

    return PriceInfo(
      originalPrice: cleaned,
      normalizedEuroPrice: null,
      currency: 'EUR',
      priceValue: null,
    );
  }

  /// Handle Poppatea price extraction
  PriceInfo _extractPoppateaPrice(String cleaned) {
    // Clean up the text
    cleaned =
        cleaned
            .replaceAll('\u00A0', ' ') // Replace non-breaking space
            .replaceAll('\n', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll('Ab ', '')
            .trim();

    // Extract price in German format (€XX,XX or XX,XX €)
    final priceMatch = RegExp(r'€?(\d+,\d{2})\s*€?').firstMatch(cleaned);
    if (priceMatch != null) {
      final priceText = priceMatch.group(1)!.replaceAll(',', '.');
      final priceValue = double.tryParse(priceText);
      if (priceValue != null && priceValue > 0) {
        return PriceInfo(
          originalPrice: cleaned,
          normalizedEuroPrice: '€${priceText.replaceAll('.', ',')}',
          currency: 'EUR',
          priceValue: priceValue,
        );
      }
    }

    return PriceInfo(
      originalPrice: cleaned,
      normalizedEuroPrice: null,
      currency: 'EUR',
      priceValue: null,
    );
  }

  /// Handle Yoshien price extraction
  PriceInfo _extractYoshienPrice(String cleaned) {
    // Clean up the text
    cleaned = cleaned.replaceAll('Ab ', '').trim();

    // Extract the first valid price
    final priceMatch = RegExp(r'(\d+[.,]\d+)\s*€').firstMatch(cleaned);
    if (priceMatch != null) {
      final priceText = priceMatch.group(1)!.replaceAll(',', '.');
      final priceValue = double.tryParse(priceText);
      if (priceValue != null && priceValue > 0) {
        return PriceInfo(
          originalPrice: cleaned,
          normalizedEuroPrice: '€${priceText.replaceAll('.', ',')}',
          currency: 'EUR',
          priceValue: priceValue,
        );
      }
    }

    return PriceInfo(
      originalPrice: cleaned,
      normalizedEuroPrice: null,
      currency: 'EUR',
      priceValue: null,
    );
  }

  /// Handle Sazen Tea price extraction
  PriceInfo _extractSazenteaPrice(String cleaned) {
    // Clean up the text
    cleaned = cleaned.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

    // Extract the first price with dollar sign
    final priceMatch = RegExp(r'\$(\d+\.\d+)').firstMatch(cleaned);
    if (priceMatch != null) {
      final usdValue = double.tryParse(priceMatch.group(1)!);
      if (usdValue != null && usdValue > 0) {
        final euroValue = usdValue * _exchangeRates['USD']!;
        return PriceInfo(
          originalPrice: cleaned,
          normalizedEuroPrice:
              '€${euroValue.toStringAsFixed(2).replaceAll('.', ',')}',
          currency: 'EUR',
          priceValue: euroValue,
        );
      }
    }

    return PriceInfo(
      originalPrice: cleaned,
      normalizedEuroPrice: null,
      currency: 'EUR',
      priceValue: null,
    );
  }
}

/// Data class to hold price information
class PriceInfo {
  final String originalPrice; // The original price text from the website
  final String? normalizedEuroPrice; // Price converted to EUR format
  final String currency; // Target currency (always EUR for consistency)
  final double? priceValue; // Numeric value for calculations and graphs

  PriceInfo({
    required this.originalPrice,
    required this.normalizedEuroPrice,
    required this.currency,
    required this.priceValue,
  });

  /// Get the display price (prioritize normalized Euro price)
  String get displayPrice => normalizedEuroPrice ?? originalPrice;

  /// Check if the price is valid for calculations
  bool get isValid => priceValue != null && priceValue! > 0;
}
