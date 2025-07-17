// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
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
      name: 'Nakamura Tokichi',
      baseUrl: 'https://global.tokichi.jp/collections/matcha',
      stockSelector:
          '', // We'll determine stock by absence of "Out of stock" text
      productSelector: '.card-wrapper', // Updated selector for Shopify theme
      nameSelector: '.card__heading a, .card__content .card__heading',
      priceSelector: '.price__current .price-item--regular, .price .price-item',
      linkSelector: '.card__heading a, .card__content a',
    ),
    'marukyu': SiteConfig(
      name: 'Marukyu-Koyamaen',
      baseUrl:
          'https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha',
      stockSelector:
          '.cart-form button:not([disabled]), .add-to-cart:not(.disabled)',
      productSelector: '.item, .product-item, .product',
      nameSelector: '.item-name, .product-name, .name, h3',
      priceSelector: '.price, .item-price, .cost',
      linkSelector: 'a, .item-link',
    ),
    'ippodo': SiteConfig(
      name: 'Ippodo Tea',
      baseUrl: 'https://global.ippodo-tea.co.jp/collections/matcha',
      stockSelector:
          '', // We'll determine stock by checking for "Add to Cart" vs "Out of Stock"
      productSelector:
          '.grid__item, .product-item, .card-wrapper', // Multiple selectors for fallback
      nameSelector:
          '.card__heading a, .card__heading, h3 a, h3, .product-title',
      priceSelector:
          '.price__current .price-item--regular, .price .price-item, .price, .cost',
      linkSelector: '.card__heading a, h3 a, .product-link, a',
    ),
  };

  Future<List<MatchaProduct>> crawlAllSites() async {
    _logger.logInfo('🚀 Starting comprehensive crawl of all sites...');
    List<MatchaProduct> allProducts = [];

    // Get existing products to track what we find vs what we don't
    List<MatchaProduct> existingProducts = await _db.getAllProducts();
    Set<String> foundProductIds = {};

    // Crawl built-in sites
    for (String siteKey in _siteConfigs.keys) {
      try {
        final config = _siteConfigs[siteKey]!;
        _logger.logProgress(
          '📡 Crawling ${config.name}...',
          siteName: config.name,
        );

        List<MatchaProduct> siteProducts = await crawlSite(siteKey);
        allProducts.addAll(siteProducts);

        // Track which products we found
        for (var product in siteProducts) {
          foundProductIds.add(product.id);
        }

        _logger.logSuccess(
          '✅ Found ${siteProducts.length} products on ${config.name}',
          siteName: config.name,
        );
      } catch (e) {
        final siteName = _siteConfigs[siteKey]?.name ?? siteKey;
        _logger.logError('❌ Error crawling $siteName: $e', siteName: siteName);
      }
    }

    // Crawl custom websites
    try {
      final customWebsites = await _db.getEnabledCustomWebsites();
      for (CustomWebsite website in customWebsites) {
        try {
          _logger.logProgress(
            '📡 Crawling ${website.name}...',
            siteName: website.name,
          );

          List<MatchaProduct> siteProducts = await crawlCustomWebsite(website);
          allProducts.addAll(siteProducts);

          // Track which products we found
          for (var product in siteProducts) {
            foundProductIds.add(product.id);
          }

          _logger.logSuccess(
            '✅ Found ${siteProducts.length} products on ${website.name}',
            siteName: website.name,
          );
        } catch (e) {
          _logger.logError('❌ Error crawling ${website.name}: $e');
        }
      }
    } catch (e) {
      _logger.logError('❌ Error loading custom websites: $e');
    }

    // Process discontinuation tracking
    _logger.logProgress(
      '🔍 Processing product availability...',
      siteName: 'System',
    );

    for (var existingProduct in existingProducts) {
      if (!foundProductIds.contains(existingProduct.id)) {
        // Product not found in current scan
        int newMissedScans = existingProduct.missedScans + 1;
        bool shouldMarkDiscontinued =
            newMissedScans >= 3 && !existingProduct.isDiscontinued;

        MatchaProduct updatedProduct = existingProduct.copyWith(
          missedScans: newMissedScans,
          isDiscontinued:
              shouldMarkDiscontinued ? true : existingProduct.isDiscontinued,
          isInStock: false, // Mark as out of stock since we didn't find it
          lastChecked: DateTime.now(),
        );

        await _db.insertOrUpdateProduct(updatedProduct);

        if (shouldMarkDiscontinued) {
          _logger.logInfo(
            '⚠️ Marked ${existingProduct.name} as discontinued after 3 missed scans',
          );
        }
      } else {
        // Product was found, reset missed scans and discontinuation if it was marked
        var currentProduct = allProducts.firstWhere(
          (p) => p.id == existingProduct.id,
        );
        if (existingProduct.missedScans > 0 || existingProduct.isDiscontinued) {
          MatchaProduct updatedProduct = currentProduct.copyWith(
            missedScans: 0,
            isDiscontinued: false,
          );

          // Update the product in our results
          int index = allProducts.indexWhere((p) => p.id == existingProduct.id);
          if (index != -1) {
            allProducts[index] = updatedProduct;
          }

          if (existingProduct.isDiscontinued) {
            _logger.logInfo(
              '✅ Removed discontinued mark from ${existingProduct.name}',
            );
          }
        }
      }
    }

    _logger.logInfo(
      '🏁 Comprehensive crawl completed. Total products found: ${allProducts.length}',
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

      // For web platform, show warning about CORS limitations
      if (kIsWeb) {
        _logger.logWarning(
          '🌐 Running on web platform - network requests may be limited by CORS policy',
          siteName: config.name,
        );
        print(
          'Warning: Web platform detected. If crawling fails, this is likely due to CORS restrictions.',
        );
      }

      // Make HTTP request with proper headers and timeout
      final client = http.Client();
      try {
        final response = await client
            .get(
              Uri.parse(config.baseUrl),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.5',
                'Accept-Encoding': 'gzip, deflate',
                'Connection': 'keep-alive',
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache',
              },
            )
            .timeout(const Duration(seconds: 30));

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

          // On web, provide more helpful error message and use sample data
          if (kIsWeb) {
            print(
              'This is likely due to CORS policy restrictions in the browser.',
            );
            print(
              'Consider using a mobile app or desktop version for full functionality.',
            );

            // Use sample data as fallback for failed HTTP requests
            _logger.logWarning(
              '🌐 Using sample data due to HTTP error',
              siteName: config.name,
            );
            products = _getSampleProducts(config.name);
            if (products.isNotEmpty) {
              _logger.logInfo(
                '📦 Generated ${products.length} sample products for ${config.name}',
                siteName: config.name,
              );
              print(
                'Added ${products.length} sample ${config.name} products for web demo.',
              );

              // Store sample products in the database
              for (MatchaProduct product in products) {
                await _checkStockChange(product);
              }
            } else {
              _logger.logWarning(
                '⚠️ No sample products available for ${config.name}',
                siteName: config.name,
              );
              print('Warning: No sample products found for ${config.name}');
            }
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      _logger.logError(
        '💥 Network error fetching ${config.name}: $e',
        siteName: config.name,
      );
      print('Error fetching ${config.name}: $e');

      if (kIsWeb) {
        print(
          'Web platform: This error is expected due to browser CORS restrictions.',
        );
        print('The crawler works on mobile devices where CORS doesn\'t apply.');

        // For web demo purposes, add some sample data
        _logger.logWarning(
          '🌐 Using sample data due to CORS restrictions',
          siteName: config.name,
        );
        products = _getSampleProducts(config.name);
        if (products.isNotEmpty) {
          _logger.logInfo(
            '📦 Generated ${products.length} sample products for ${config.name}',
            siteName: config.name,
          );
          print(
            'Added ${products.length} sample ${config.name} products for web demo.',
          );

          // Store sample products in the database
          for (MatchaProduct product in products) {
            await _checkStockChange(product);
          }
        } else {
          _logger.logWarning(
            '⚠️ No sample products available for ${config.name}',
            siteName: config.name,
          );
          print('Warning: No sample products found for ${config.name}');
        }
      }
    }

    return products;
  }

  Future<List<MatchaProduct>> crawlCustomWebsite(CustomWebsite website) async {
    List<MatchaProduct> products = [];
    final client = http.Client();

    try {
      final response = await client
          .get(
            Uri.parse(website.baseUrl),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.5',
              'Accept-Encoding': 'gzip, deflate',
              'Connection': 'keep-alive',
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        _logger.logInfo(
          '📄 Page fetched successfully, parsing products...',
          siteName: website.name,
        );
        products = await _parseCustomWebsiteProducts(response.body, website);

        // Update test status on successful crawl
        await _db.updateWebsiteTestStatus(website.id, 'success');
      } else {
        _logger.logError(
          '🚫 Failed to fetch ${website.name}: HTTP ${response.statusCode}',
          siteName: website.name,
        );
        await _db.updateWebsiteTestStatus(website.id, 'failed');
      }
    } catch (e) {
      _logger.logError(
        '💥 Network error fetching ${website.name}: $e',
        siteName: website.name,
      );
      await _db.updateWebsiteTestStatus(website.id, 'failed');
    } finally {
      client.close();
    }

    // Save or update products and check for stock changes
    for (MatchaProduct product in products) {
      await _checkStockChange(product);
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

        if (nameElement != null) {
          String name = nameElement.text.trim();
          String? price = priceElement?.text.trim().replaceAll('\$', '');
          String? href = linkElement?.attributes['href'];

          // Determine stock status based on site
          bool isInStock = _determineStockStatus(
            productElement,
            config,
            siteKey,
          );

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

    // If no products were parsed and we're on web, use sample data as fallback
    if (products.isEmpty && kIsWeb) {
      _logger.logWarning(
        '⚠️ No products parsed from HTML, using sample data as fallback',
        siteName: config.name,
      );
      print(
        'Warning: No products parsed for ${config.name}, using sample data',
      );

      final sampleProducts = _getSampleProducts(config.name);
      for (MatchaProduct product in sampleProducts) {
        await _checkStockChange(product);
      }
      return sampleProducts;
    }

    return products;
  }

  Future<List<MatchaProduct>> _parseCustomWebsiteProducts(
    String html,
    CustomWebsite website,
  ) async {
    final document = parse(html);
    final productElements = document.querySelectorAll(website.productSelector);
    List<MatchaProduct> products = [];

    _logger.logProgress(
      '🔍 Found ${productElements.length} product elements to parse...',
      siteName: website.name,
    );

    for (Element productElement in productElements) {
      try {
        // Extract product information
        final nameElement = productElement.querySelector(website.nameSelector);
        final priceElement = productElement.querySelector(
          website.priceSelector,
        );
        final linkElement = productElement.querySelector(website.linkSelector);

        if (nameElement != null) {
          String name = nameElement.text.trim();
          String? price = priceElement?.text.trim().replaceAll('\$', '');
          String? href = linkElement?.attributes['href'];

          // Determine stock status
          bool isInStock = _determineCustomWebsiteStockStatus(
            productElement,
            website,
          );

          // Build full URL
          String productUrl =
              href != null
                  ? (href.startsWith('http')
                      ? href
                      : _buildFullUrl(website.baseUrl, href))
                  : website.baseUrl;

          MatchaProduct product = MatchaProduct.create(
            name: name,
            site: website.name,
            url: productUrl,
            isInStock: isInStock,
            price: price,
          );

          products.add(product);
        }
      } catch (e) {
        _logger.logError('❌ Error parsing product element: $e');
      }
    }

    return products;
  }

  bool _determineCustomWebsiteStockStatus(
    Element productElement,
    CustomWebsite website,
  ) {
    // If stock selector is provided, use it
    if (website.stockSelector.isNotEmpty) {
      final stockElement = productElement.querySelector(website.stockSelector);
      return stockElement != null;
    }

    // Otherwise, check for common stock indicators in text
    final elementText = productElement.text.toLowerCase();

    // Check for out of stock indicators
    if (elementText.contains('out of stock') ||
        elementText.contains('sold out') ||
        elementText.contains('unavailable') ||
        elementText.contains('temporarily unavailable')) {
      return false;
    }

    // Check for in stock indicators
    if (elementText.contains('in stock') ||
        elementText.contains('available') ||
        elementText.contains('add to cart') ||
        elementText.contains('buy now')) {
      return true;
    }

    // Default to in stock if no clear indicators
    return true;
  }

  bool _determineStockStatus(
    Element productElement,
    SiteConfig config,
    String siteKey,
  ) {
    switch (siteKey) {
      case 'tokichi':
        // For Tokichi, check if "Out of stock" text is present
        final outOfStockText = productElement.text.toLowerCase();
        return !outOfStockText.contains('out of stock');

      case 'ippodo':
        // For Ippodo, check for "Add to Cart" vs "Out of Stock" text
        final elementText = productElement.text.toLowerCase();
        if (elementText.contains('add to cart')) {
          return true;
        } else if (elementText.contains('out of stock')) {
          return false;
        }
        // If neither found, check for specific button selectors
        final addToCartButton = productElement.querySelector(
          'button:not([disabled]), .btn:not(.disabled)',
        );
        return addToCartButton != null;

      case 'marukyu':
        // For Marukyu, use the original selector method
        final stockElement = productElement.querySelector(config.stockSelector);
        return stockElement != null;

      default:
        // Fallback: check for generic stock indicators
        final stockElement = productElement.querySelector(config.stockSelector);
        return stockElement != null;
    }
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

  /// Creates sample matcha products for web demo when CORS blocks real requests
  List<MatchaProduct> _getSampleProducts(String siteName) {
    final now = DateTime.now();

    switch (siteName) {
      case 'Nakamura Tokichi':
        return [
          MatchaProduct(
            id: 'tokichi_demo_1',
            name: 'Matcha Starter, 100g Bag',
            normalizedName: 'matcha starter 100g bag',
            site: siteName,
            url: 'https://global.tokichi.jp/products/matcha-starter-100g',
            price: '€60.00 EUR',
            priceValue: 60.0,
            currency: 'EUR',
            isInStock: true,
            lastChecked: now,
            firstSeen: now,
            category: 'Matcha Powder',
            description:
                'Perfect for beginners, this matcha offers a balanced taste profile.',
            imageUrl: '',
            weight: 100,
          ),
          MatchaProduct(
            id: 'tokichi_demo_2',
            name: 'Premium Ceremonial Matcha',
            normalizedName: 'premium ceremonial matcha',
            site: siteName,
            url: 'https://global.tokichi.jp/products/premium-ceremonial',
            price: '€85.00 EUR',
            priceValue: 85.0,
            currency: 'EUR',
            isInStock: false,
            lastChecked: now,
            firstSeen: now,
            category: 'Ceremonial Grade',
            description: 'High-grade matcha for traditional tea ceremony.',
            imageUrl: '',
            weight: 30,
          ),
        ];

      case 'Ippodo Tea':
        return [
          MatchaProduct(
            id: 'ippodo_demo_1',
            name: 'Matcha To-Go Packets',
            normalizedName: 'matcha to go packets',
            site: siteName,
            url: 'https://global.ippodo-tea.co.jp/products/matcha-to-go',
            price: '¥1,200',
            priceValue: 1200.0,
            currency: 'JPY',
            isInStock: true,
            lastChecked: now,
            firstSeen: now,
            category: 'Portable Matcha',
            description:
                'Convenient single-serve matcha packets for on-the-go preparation.',
            imageUrl: '',
            weight: 20,
          ),
          MatchaProduct(
            id: 'ippodo_demo_2',
            name: 'Ummon-no-mukashi Matcha',
            normalizedName: 'ummon no mukashi matcha',
            site: siteName,
            url: 'https://global.ippodo-tea.co.jp/products/ummon-no-mukashi',
            price: '¥3,240',
            priceValue: 3240.0,
            currency: 'JPY',
            isInStock: true,
            lastChecked: now,
            firstSeen: now,
            category: 'Premium Matcha',
            description: 'Traditional matcha with rich umami flavor.',
            imageUrl: '',
            weight: 40,
          ),
        ];

      case 'Marukyu-Koyamaen':
        return [
          MatchaProduct(
            id: 'marukyu_demo_1',
            name: 'Hatsu-mukashi Matcha',
            normalizedName: 'hatsu mukashi matcha',
            site: siteName,
            url: 'https://www.marukyu-koyamaen.co.jp/products/hatsu-mukashi',
            price: '¥2,160',
            priceValue: 2160.0,
            currency: 'JPY',
            isInStock: true,
            lastChecked: now,
            firstSeen: now,
            category: 'Traditional Matcha',
            description: 'Classic matcha with well-balanced flavor profile.',
            imageUrl: '',
            weight: 40,
          ),
          MatchaProduct(
            id: 'marukyu_demo_2',
            name: 'Wako-no-shiro Matcha',
            normalizedName: 'wako no shiro matcha',
            site: siteName,
            url: 'https://www.marukyu-koyamaen.co.jp/products/wako-no-shiro',
            price: '¥5,400',
            priceValue: 5400.0,
            currency: 'JPY',
            isInStock: false,
            lastChecked: now,
            firstSeen: now,
            category: 'Premium Grade',
            description: 'Premium matcha with exceptional quality and taste.',
            imageUrl: '',
            weight: 40,
          ),
        ];

      default:
        return [];
    }
  }

  Future<void> testCrawl() async {
    print('Starting test crawl...');

    // Test each site individually
    for (String siteKey in _siteConfigs.keys) {
      final config = _siteConfigs[siteKey]!;
      print('\n=== Testing ${config.name} ===');

      try {
        List<MatchaProduct> products = await crawlSite(siteKey);
        print('✅ ${config.name}: Found ${products.length} products');

        for (MatchaProduct product in products) {
          print(
            '  - ${product.name} (${product.isInStock ? "In Stock" : "Out of Stock"})',
          );
        }
      } catch (e) {
        print('❌ ${config.name}: Error - $e');
      }
    }

    print('\n=== Full Crawl Test ===');
    List<MatchaProduct> allProducts = await crawlAllSites();
    print('Found ${allProducts.length} products total:');

    for (MatchaProduct product in allProducts) {
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
