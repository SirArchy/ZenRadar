// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import '../models/matcha_product.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'crawler_logger.dart';

class CrawlerService {
  static final CrawlerService _instance = CrawlerService._internal();
  factory CrawlerService() => _instance;
  CrawlerService._internal();

  static CrawlerService get instance => _instance;

  final dynamic _db = DatabaseService.platformService;
  final NotificationService _notifications = NotificationService.instance;
  final CrawlerLogger _logger = CrawlerLogger.instance;

  // Site configurations
  final Map<String, SiteConfig> _siteConfigs = {
    'tokichi': SiteConfig(
      name: 'Tokichi',
      baseUrl: 'https://global.tokichi.jp/collections/matcha',
      stockSelector: '.product-form__cart-submit:not([disabled])',
      productSelector: '.product-item',
      nameSelector: '.product-item__title',
      priceSelector: '.price',
      linkSelector: 'a',
    ),
    'marukyu': SiteConfig(
      name: 'Marukyu-Koyamaen',
      baseUrl:
          'https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha?viewall=1',
      stockSelector: '.add-to-cart:not(.disabled)',
      productSelector: '.product-item',
      nameSelector: '.product-name',
      priceSelector: '.price',
      linkSelector: 'a',
    ),
    'ippodo': SiteConfig(
      name: 'Ippodo Tea',
      baseUrl: 'https://global.ippodo-tea.co.jp/collections/matcha',
      stockSelector: '.btn-product-form:not([disabled])',
      productSelector: '.product-item',
      nameSelector: '.product-item__title',
      priceSelector: '.price',
      linkSelector: 'a',
    ),
  };

  Future<List<MatchaProduct>> crawlAllSites() async {
    _logger.logInfo('🚀 Starting crawl of all sites...');
    List<MatchaProduct> allProducts = [];

    for (String siteKey in _siteConfigs.keys) {
      try {
        final config = _siteConfigs[siteKey]!;
        _logger.logProgress(
          '📡 Crawling ${config.name}...',
          siteName: config.name,
        );

        List<MatchaProduct> siteProducts = await crawlSite(siteKey);
        allProducts.addAll(siteProducts);

        _logger.logSuccess(
          '✅ Found ${siteProducts.length} products on ${config.name}',
          siteName: config.name,
        );
      } catch (e) {
        final siteName = _siteConfigs[siteKey]?.name ?? siteKey;
        _logger.logError('❌ Error crawling $siteName: $e', siteName: siteName);
        print('Error crawling $siteKey: $e');
      }
    }

    _logger.logInfo(
      '🏁 Crawl completed. Total products found: ${allProducts.length}',
    );
    return allProducts;
  }

  Future<List<MatchaProduct>> crawlSite(String siteKey) async {
    if (!_siteConfigs.containsKey(siteKey)) {
      throw ArgumentError('Unknown site: $siteKey');
    }

    final config = _siteConfigs[siteKey]!;
    List<MatchaProduct> products = [];

    try {
      _logger.logProgress(
        '🌐 Fetching ${config.name} page...',
        siteName: config.name,
      );

      // Make HTTP request with proper headers
      final response = await http.get(
        Uri.parse(config.baseUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
        },
      );

      if (response.statusCode == 200) {
        _logger.logInfo(
          '📄 Page fetched successfully, parsing products...',
          siteName: config.name,
        );
        products = await _parseProducts(response.body, config, siteKey);
      } else {
        _logger.logError(
          '🚫 Failed to fetch ${config.name}: HTTP ${response.statusCode}',
          siteName: config.name,
        );
        print('Failed to fetch ${config.name}: ${response.statusCode}');
      }
    } catch (e) {
      _logger.logError(
        '💥 Network error fetching ${config.name}: $e',
        siteName: config.name,
      );
      print('Error fetching ${config.name}: $e');
    }

    return products;
  }

  Future<List<MatchaProduct>> _parseProducts(
    String html,
    SiteConfig config,
    String siteKey,
  ) async {
    final document = parse(html);
    final productElements = document.querySelectorAll(config.productSelector);
    List<MatchaProduct> products = [];

    _logger.logProgress(
      '🔍 Found ${productElements.length} product elements to parse...',
      siteName: config.name,
    );

    for (Element productElement in productElements) {
      try {
        // Extract product information
        final nameElement = productElement.querySelector(config.nameSelector);
        final priceElement = productElement.querySelector(config.priceSelector);
        final linkElement = productElement.querySelector(config.linkSelector);
        final stockElement = productElement.querySelector(config.stockSelector);

        if (nameElement != null) {
          String name = nameElement.text.trim();
          String? price = priceElement?.text.trim();
          String? href = linkElement?.attributes['href'];
          bool isInStock = stockElement != null;

          // Build full URL
          String productUrl =
              href != null
                  ? (href.startsWith('http')
                      ? href
                      : _buildFullUrl(config.baseUrl, href))
                  : config.baseUrl;

          MatchaProduct product = MatchaProduct.create(
            name: name,
            site: config.name,
            url: productUrl,
            isInStock: isInStock,
            price: price,
          );

          products.add(product);

          _logger.logProgress(
            '📦 Parsed: $name - ${isInStock ? "✅ In Stock" : "❌ Out of Stock"}',
            siteName: config.name,
          );

          // Check for stock changes
          await _checkStockChange(product);
        }
      } catch (e) {
        _logger.logError(
          '⚠️ Error parsing product element: $e',
          siteName: config.name,
        );
        print('Error parsing product element: $e');
      }
    }

    return products;
  }

  String _buildFullUrl(String baseUrl, String relativeUrl) {
    Uri baseUri = Uri.parse(baseUrl);
    Uri relativeUri = Uri.parse(relativeUrl);
    return baseUri.resolveUri(relativeUri).toString();
  }

  Future<void> _checkStockChange(MatchaProduct newProduct) async {
    // Get existing product from database
    MatchaProduct? existingProduct = await _db.getProduct(newProduct.id);

    if (existingProduct != null) {
      // Check if stock status changed
      if (!existingProduct.isInStock && newProduct.isInStock) {
        // Product came back in stock - send notification
        _logger.logSuccess(
          '🎉 STOCK ALERT: ${newProduct.name} is back in stock!',
          siteName: newProduct.site,
        );

        await _notifications.showStockAlert(
          productName: newProduct.name,
          siteName: newProduct.site,
          productId: newProduct.id,
        );

        // Record stock change
        await _db.recordStockChange(newProduct.id, true);
      } else if (existingProduct.isInStock && !newProduct.isInStock) {
        // Product went out of stock
        await _db.recordStockChange(newProduct.id, false);
      }
    } else {
      // New product - record initial stock status
      if (newProduct.isInStock) {
        await _db.recordStockChange(newProduct.id, true);
      }
    }

    // Insert or update product in database (this handles both cases)
    await _db.insertOrUpdateProduct(newProduct);
  }

  Future<void> testCrawl() async {
    print('Starting test crawl...');
    List<MatchaProduct> products = await crawlAllSites();
    print('Found ${products.length} products:');

    for (MatchaProduct product in products) {
      print(
        '${product.site}: ${product.name} - ${product.isInStock ? "In Stock" : "Out of Stock"}',
      );
    }
  }
}

class SiteConfig {
  final String name;
  final String baseUrl;
  final String stockSelector;
  final String productSelector;
  final String nameSelector;
  final String priceSelector;
  final String linkSelector;

  SiteConfig({
    required this.name,
    required this.baseUrl,
    required this.stockSelector,
    required this.productSelector,
    required this.nameSelector,
    required this.priceSelector,
    required this.linkSelector,
  });
}
