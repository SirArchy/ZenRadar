// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import '../models/matcha_product.dart';
import 'database_service.dart';
import 'notification_service.dart';

class CrawlerService {
  static final CrawlerService _instance = CrawlerService._internal();
  factory CrawlerService() => _instance;
  CrawlerService._internal();

  static CrawlerService get instance => _instance;

  final DatabaseService _db = DatabaseService.instance;
  final NotificationService _notifications = NotificationService.instance;

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
    List<MatchaProduct> allProducts = [];

    for (String siteKey in _siteConfigs.keys) {
      try {
        List<MatchaProduct> siteProducts = await crawlSite(siteKey);
        allProducts.addAll(siteProducts);
      } catch (e) {
        print('Error crawling $siteKey: $e');
      }
    }

    return allProducts;
  }

  Future<List<MatchaProduct>> crawlSite(String siteKey) async {
    if (!_siteConfigs.containsKey(siteKey)) {
      throw ArgumentError('Unknown site: $siteKey');
    }

    final config = _siteConfigs[siteKey]!;
    List<MatchaProduct> products = [];

    try {
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
        products = await _parseProducts(response.body, config, siteKey);
      } else {
        print('Failed to fetch ${config.name}: ${response.statusCode}');
      }
    } catch (e) {
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

          // Generate unique ID
          String productId = '${siteKey}_${name.hashCode}';

          // Build full URL
          String productUrl =
              href != null
                  ? (href.startsWith('http')
                      ? href
                      : _buildFullUrl(config.baseUrl, href))
                  : config.baseUrl;

          MatchaProduct product = MatchaProduct(
            id: productId,
            name: name,
            site: config.name,
            url: productUrl,
            isInStock: isInStock,
            lastChecked: DateTime.now(),
            price: price,
          );

          products.add(product);

          // Check for stock changes
          await _checkStockChange(product);
        }
      } catch (e) {
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

      // Update product in database
      await _db.updateProduct(newProduct);
    } else {
      // New product - insert into database
      await _db.insertProduct(newProduct);

      // If it's in stock, optionally send notification for new product
      if (newProduct.isInStock) {
        await _db.recordStockChange(newProduct.id, true);
      }
    }
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
