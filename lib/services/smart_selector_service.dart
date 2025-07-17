import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;

class SmartSelectorService {
  static final SmartSelectorService _instance =
      SmartSelectorService._internal();
  factory SmartSelectorService() => _instance;
  SmartSelectorService._internal();

  static SmartSelectorService get instance => _instance;

  /// Analyzes a website and automatically detects product selectors
  Future<Map<String, String>> analyzeWebsite(String url) async {
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
            },
          )
          .timeout(const Duration(seconds: 30));

      client.close();

      if (response.statusCode == 200) {
        return _analyzeHtml(response.body);
      } else {
        throw Exception('Failed to fetch page: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error analyzing website: $e');
    }
  }

  Map<String, String> _analyzeHtml(String html) {
    final document = parse(html);

    return {
      'productSelector': _detectProductSelector(document),
      'nameSelector': _detectNameSelector(document),
      'priceSelector': _detectPriceSelector(document),
      'linkSelector': _detectLinkSelector(document),
      'stockSelector': _detectStockSelector(document),
    };
  }

  /// Detects product container elements
  String _detectProductSelector(Document document) {
    // Common patterns for product containers
    final patterns = [
      '.product',
      '.product-item',
      '.card',
      '.card-wrapper',
      '.grid__item',
      '.item',
      '.product-card',
      '.product-tile',
      '[data-product]',
      '.listing-item',
      '.shop-item',
    ];

    for (String pattern in patterns) {
      final elements = document.querySelectorAll(pattern);
      if (elements.length >= 2 && elements.length <= 50) {
        // Check if these elements contain typical product info
        final firstElement = elements.first;
        if (_hasProductCharacteristics(firstElement)) {
          return pattern;
        }
      }
    }

    // Fallback: try to detect by structure
    return _detectByStructure(document);
  }

  /// Detects product name selectors
  String _detectNameSelector(Document document) {
    final patterns = [
      '.product-name',
      '.product-title',
      '.card__heading',
      '.card__heading a',
      '.item-name',
      '.name',
      'h1',
      'h2',
      'h3',
      '.title',
      '.product-info h3',
      '.product-info h2',
      '[data-product-title]',
    ];

    return _findBestSelector(document, patterns, _isLikelyProductName);
  }

  /// Detects price selectors
  String _detectPriceSelector(Document document) {
    final patterns = [
      '.price',
      '.price__current',
      '.price-item',
      '.cost',
      '.amount',
      '.price-value',
      '.product-price',
      '.item-price',
      '[data-price]',
      '.money',
      '.price-regular',
    ];

    return _findBestSelector(document, patterns, _isLikelyPrice);
  }

  /// Detects link selectors
  String _detectLinkSelector(Document document) {
    final patterns = [
      'a',
      '.product-link',
      '.card__heading a',
      '.item-link',
      '.product-url',
    ];

    return _findBestSelector(document, patterns, _isLikelyProductLink);
  }

  /// Detects stock status selectors
  String _detectStockSelector(Document document) {
    final patterns = [
      '.add-to-cart:not(.disabled)',
      '.btn-cart:not(.disabled)',
      '.in-stock',
      '.available',
      '.stock-status',
      'button:not([disabled])',
      '.add-to-bag',
      '.buy-now',
    ];

    return _findBestSelector(document, patterns, _isLikelyStockIndicator);
  }

  String _findBestSelector(
    Document document,
    List<String> patterns,
    bool Function(Element) validator,
  ) {
    for (String pattern in patterns) {
      final elements = document.querySelectorAll(pattern);
      if (elements.isNotEmpty) {
        // Check if any of these elements pass the validator
        if (elements.any(validator)) {
          return pattern;
        }
      }
    }
    return patterns.first; // Return first as fallback
  }

  bool _hasProductCharacteristics(Element element) {
    final text = element.text.toLowerCase();
    final html = element.outerHtml.toLowerCase();

    // Check for price indicators
    bool hasPrice =
        RegExp(r'[\$€¥£]\d+|price|cost|\d+\.\d+').hasMatch(text) ||
        html.contains('price') ||
        html.contains('cost');

    // Check for product name indicators
    bool hasName =
        element.querySelector('h1, h2, h3, .title, .name') != null ||
        text.length > 10; // Reasonable name length

    // Check for links
    bool hasLink = element.querySelector('a') != null;

    return hasPrice && hasName && hasLink;
  }

  bool _isLikelyProductName(Element element) {
    final text = element.text.trim();
    return text.isNotEmpty &&
        text.length >= 3 &&
        text.length <= 200 &&
        !_isLikelyPrice(element) &&
        !text.toLowerCase().contains('add to cart') &&
        !text.toLowerCase().contains('buy now');
  }

  bool _isLikelyPrice(Element element) {
    final text = element.text.toLowerCase();
    return RegExp(r'[\$€¥£]\d+|\d+\.\d+|\d+,\d+|price|cost').hasMatch(text);
  }

  bool _isLikelyProductLink(Element element) {
    if (element.localName?.toLowerCase() != 'a') return false;

    final href = element.attributes['href'] ?? '';
    final text = element.text.toLowerCase();

    return href.isNotEmpty &&
        !href.startsWith('#') &&
        !href.startsWith('mailto:') &&
        !text.contains('cart') &&
        !text.contains('checkout');
  }

  bool _isLikelyStockIndicator(Element element) {
    final text = element.text.toLowerCase();
    final classes = element.classes.join(' ').toLowerCase();

    return (text.contains('add to cart') ||
            text.contains('buy now') ||
            text.contains('in stock') ||
            text.contains('available')) ||
        (classes.contains('cart') ||
            classes.contains('buy') ||
            classes.contains('stock'));
  }

  String _detectByStructure(Document document) {
    // Try to find repeated elements that might be products
    final commonTags = ['div', 'article', 'section', 'li'];

    for (String tag in commonTags) {
      final elements = document.querySelectorAll(tag);
      if (elements.length >= 3 && elements.length <= 50) {
        // Group by similar structure
        final groups = <String, List<Element>>{};

        for (Element element in elements) {
          final key = _getStructureKey(element);
          groups[key] = (groups[key] ?? [])..add(element);
        }

        // Find the largest group with product characteristics
        for (MapEntry<String, List<Element>> entry in groups.entries) {
          if (entry.value.length >= 3 &&
              _hasProductCharacteristics(entry.value.first)) {
            // Generate selector for this group
            return _generateSelectorForElement(entry.value.first);
          }
        }
      }
    }

    return 'div'; // Ultimate fallback
  }

  String _getStructureKey(Element element) {
    // Create a key based on element structure
    final children = element.children.map((e) => e.localName).join(',');
    final classes = element.classes.join(' ');
    return '${element.localName}:$classes:$children';
  }

  String _generateSelectorForElement(Element element) {
    if (element.id.isNotEmpty) {
      return '#${element.id}';
    }

    if (element.classes.isNotEmpty) {
      return '.${element.classes.first}';
    }

    return element.localName?.toLowerCase() ?? 'div';
  }

  /// Test the detected selectors against the website
  Future<Map<String, dynamic>> testSelectors(
    String url,
    Map<String, String> selectors,
  ) async {
    try {
      final client = http.Client();

      final response = await client
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          )
          .timeout(const Duration(seconds: 30));

      client.close();

      if (response.statusCode == 200) {
        return _testSelectorsOnHtml(response.body, selectors);
      } else {
        throw Exception('Failed to fetch page for testing');
      }
    } catch (e) {
      throw Exception('Error testing selectors: $e');
    }
  }

  Map<String, dynamic> _testSelectorsOnHtml(
    String html,
    Map<String, String> selectors,
  ) {
    final document = parse(html);
    final results = <String, dynamic>{};

    // Test product selector
    final products = document.querySelectorAll(
      selectors['productSelector'] ?? '',
    );
    results['productCount'] = products.length;

    if (products.isNotEmpty) {
      final firstProduct = products.first;

      // Test other selectors on the first product
      results['nameFound'] =
          firstProduct.querySelector(selectors['nameSelector'] ?? '') != null;
      results['priceFound'] =
          firstProduct.querySelector(selectors['priceSelector'] ?? '') != null;
      results['linkFound'] =
          firstProduct.querySelector(selectors['linkSelector'] ?? '') != null;

      // Get sample data
      results['sampleName'] =
          firstProduct
              .querySelector(selectors['nameSelector'] ?? '')
              ?.text
              .trim() ??
          '';
      results['samplePrice'] =
          firstProduct
              .querySelector(selectors['priceSelector'] ?? '')
              ?.text
              .trim() ??
          '';
      results['sampleLink'] =
          firstProduct
              .querySelector(selectors['linkSelector'] ?? '')
              ?.attributes['href'] ??
          '';
    } else {
      results['nameFound'] = false;
      results['priceFound'] = false;
      results['linkFound'] = false;
      results['sampleName'] = '';
      results['samplePrice'] = '';
      results['sampleLink'] = '';
    }

    return results;
  }
}
