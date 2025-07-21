// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import '../models/matcha_product.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'crawler_logger.dart';
import 'settings_service.dart';

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
          'https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha?currency=USD',
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
          '.out-of-stock', // Products are out of stock if this element exists
      productSelector:
          '.m-product-card', // Updated to use the correct Ippodo selector
      nameSelector:
          '.m-product-card__name, .m-product-card__body a', // Updated name selector priority
      priceSelector:
          '.m-product-card__price', // Updated to use the correct price selector
      linkSelector: 'a[href*="/products/"]',
    ),
    'yoshien': SiteConfig(
      name: 'Yoshi En',
      baseUrl: 'https://www.yoshien.com/matcha/matcha-tee/',
      stockSelector:
          'a[href*="matcha"]', // Links to matcha products indicate availability
      productSelector:
          '.cs-product-tile', // Products are in cs-product-tile containers
      nameSelector:
          '.cs-product-tile__name, .cs-product-tile__name-link', // Product name in cs-product-tile__name
      priceSelector:
          '.cs-product-tile__price', // Price in cs-product-tile__price
      linkSelector: 'a[href*="/matcha-"]',
    ),
    'matcha-karu': SiteConfig(
      name: 'Matcha Kāru',
      baseUrl: 'https://matcha-karu.com/collections/matcha-tee',
      stockSelector: '.price',
      productSelector: '.product-item',
      nameSelector:
          '.product-item-meta__title, .product-item__info a', // Updated to get actual product name
      priceSelector:
          '.price:first-child', // Get first price element to avoid unit price
      linkSelector: '.product-item-meta__title, .product-item__info a',
    ),
    'sho-cha': SiteConfig(
      name: 'Sho-Cha',
      baseUrl: 'https://www.sho-cha.com/teeshop',
      stockSelector: '.product-price',
      productSelector: '.ProductList-item',
      nameSelector: '.ProductList-title a, .ProductList-title',
      priceSelector: '.product-price',
      linkSelector: '.ProductList-title a, a',
    ),
    'sazentea': SiteConfig(
      name: 'Sazen Tea',
      baseUrl: 'https://www.sazentea.com/en/products/c21-matcha',
      stockSelector: '.product-price', // Products with prices are available
      productSelector: '.product', // Products are in .product containers
      nameSelector: '.product-name', // Product name is in .product-name
      priceSelector: '.product-price', // Price is in .product-price
      linkSelector: 'a[href*="/products/"]', // Product links to detail pages
    ),
    'mamecha': SiteConfig(
      name: 'Mamecha',
      baseUrl: 'https://www.mamecha.com/online-shopping-1/',
      stockSelector:
          'h4, a[href*="product"]', // Product names indicate availability
      productSelector:
          '[id*="cc-m-product"]', // Products in cc-m-product containers
      nameSelector: 'h4', // Product names in h4 elements
      priceSelector:
          '.cc-shop-product-price-current, option.j-product__variants__item', // Prices in current price or variant options
      linkSelector: 'a[href*="/j/shop/"]', // Product links to shop pages
    ),
    'enjoyemeri': SiteConfig(
      name: 'Emeri',
      baseUrl: 'https://www.enjoyemeri.com/collections/shop-all',
      stockSelector: '.price',
      productSelector: '.product-card',
      nameSelector: 'h3',
      priceSelector: '.price',
      linkSelector: 'a',
    ),
    'poppatea': SiteConfig(
      name: 'Poppatea',
      baseUrl: 'https://poppatea.com/de-de/collections/all-teas',
      stockSelector:
          'h3', // Use h3 as stock indicator - if h3 exists, product exists
      productSelector: '.card__container', // Product containers
      nameSelector: 'h3', // Product names in h3 elements
      priceSelector:
          '.price__regular', // Prices in price__regular elements (not price-item)
      linkSelector: 'a[href*="/products/"]', // Product links
    ),
  };

  Future<List<MatchaProduct>> crawlAllSites() async {
    _logger.logInfo('🚀 Starting comprehensive crawl of all sites...');

    // Get user settings to check which sites are enabled
    final userSettings = await SettingsService.instance.getSettings();
    final enabledSiteKeys = userSettings.enabledSites;

    return await crawlSelectedSites(enabledSiteKeys);
  }

  /// Crawl only the specified sites
  Future<List<MatchaProduct>> crawlSelectedSites(
    List<String> selectedSiteKeys,
  ) async {
    _logger.logInfo(
      '� Starting crawl of selected sites: ${selectedSiteKeys.join(', ')}',
    );
    List<MatchaProduct> allProducts = [];

    _logger.logInfo('📋 Selected sites: ${selectedSiteKeys.join(', ')}');

    // Get existing products to track what we find vs what we don't
    List<MatchaProduct> existingProducts = await _db.getAllProducts();
    Set<String> foundProductIds = {};

    // Crawl built-in sites (only selected ones)
    for (String siteKey in _siteConfigs.keys) {
      // Skip sites that are not in the selected list
      if (!selectedSiteKeys.contains(siteKey)) {
        final siteName = _siteConfigs[siteKey]?.name ?? siteKey;
        _logger.logInfo('⏭️ Skipping unselected site: $siteName');
        continue;
      }

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

    // Crawl custom websites (include all enabled custom sites for now)
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

  /// Get all available built-in site keys
  List<String> getAvailableSites() {
    return _siteConfigs.keys.toList();
  }

  /// Get site display name from site key
  String getSiteName(String siteKey) {
    return _siteConfigs[siteKey]?.name ?? siteKey;
  }

  /// Get all site names with their keys for display purposes
  Map<String, String> getSiteNamesMap() {
    final result = <String, String>{};
    for (final entry in _siteConfigs.entries) {
      result[entry.key] = entry.value.name;
    }
    return result;
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
          String? price = priceElement?.text.trim();
          String? href = linkElement?.attributes['href'];

          // Special handling for Ippodo - extract name from img alt if text is empty
          if (siteKey == 'ippodo' &&
              name.isEmpty &&
              nameElement.localName == 'img') {
            name = nameElement.attributes['alt']?.trim() ?? '';
          }

          // Clean and process price
          if (price != null) {
            price = _cleanPrice(price, siteKey);
          }

          // Special handling for Sazen Tea product containers
          if (siteKey == 'sazentea' && name.isEmpty) {
            // For Sazen Tea, get name from .product-name
            final nameElement = productElement.querySelector('.product-name');
            if (nameElement != null) {
              name = nameElement.text.trim();
            }

            // Get link from the product container
            final linkElement = productElement.querySelector(
              'a[href*="/products/"]',
            );
            if (linkElement != null) {
              href = linkElement.attributes['href'];
            }
          }

          // Special handling for table-based sites (legacy - keeping for other sites)
          if (name.isEmpty && productElement.localName == 'tr') {
            // For table-based sites, extract name from link text
            final linkElements = productElement.querySelectorAll('a');
            for (var linkEl in linkElements) {
              final linkText = linkEl.text.trim();
              final linkHref = linkEl.attributes['href'];
              if (linkText.isNotEmpty &&
                  linkHref != null &&
                  (linkHref.contains('matcha') ||
                      linkHref.contains('product'))) {
                name = linkText;
                href = linkHref;
                break;
              }
            }

            // For table sites, extract price from table cells
            if (price == null || price.isEmpty) {
              final cells = productElement.querySelectorAll('td');
              for (var cell in cells) {
                final cellText = cell.text.trim();
                if (RegExp(r'[\$€£¥]\s*\d+[.,]\d+').hasMatch(cellText)) {
                  price = _cleanPrice(cellText, siteKey);
                  break;
                }
              }
            }
          }

          // Special handling for sites where name needs to be extracted from URL
          if (name.isEmpty && href != null && siteKey == 'matcha-karu') {
            // Extract product name from Matcha Kāru URL path
            final urlPath = href.split('/').last;
            name = urlPath
                .replaceAll('-', ' ')
                .replaceAll('_', ' ')
                .split(' ')
                .map(
                  (word) =>
                      word.isNotEmpty
                          ? word[0].toUpperCase() + word.substring(1)
                          : word,
                )
                .join(' ');
          }

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
            priceValue: _extractPriceValue(price),
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
            priceValue: _extractPriceValue(price),
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
        // For Ippodo, check for .out-of-stock class (inverse logic - out of stock if element exists)
        final outOfStockElement = productElement.querySelector('.out-of-stock');
        return outOfStockElement ==
            null; // In stock if NO .out-of-stock element found

      case 'marukyu':
        // For Marukyu, check for stock classes (positive: instock, negative: outofstock)
        if (productElement.classes.contains('instock')) {
          return true; // Explicitly in stock
        }
        if (productElement.classes.contains('outofstock')) {
          return false; // Explicitly out of stock
        }
        // Fallback: assume in stock if no explicit stock class
        return true;

      case 'yoshien':
        // For Yoshi En, check if we have a valid product link and name
        final nameElement = productElement.querySelector(config.nameSelector);
        if (nameElement == null || nameElement.text.trim().isEmpty) {
          return false;
        }

        // Check for out-of-stock class
        if (productElement.classes.contains('cs-product-tile--out-of-stock')) {
          return false;
        }

        final elementText = productElement.text.toLowerCase();
        if (elementText.contains('ausverkauft') ||
            elementText.contains('out of stock') ||
            elementText.contains('sold out') ||
            elementText.contains('wieder verfügbar')) {
          return false;
        }

        // If we found a product name and link, it's likely in stock
        final linkElement = productElement.querySelector(config.linkSelector);
        return linkElement != null && nameElement.text.trim().isNotEmpty;

      case 'matcha-karu':
        // For Matcha Kāru (Shopify), check if price is present
        final priceElement = productElement.querySelector(config.priceSelector);
        if (priceElement == null || priceElement.text.trim().isEmpty) {
          return false;
        }

        final elementText = productElement.text.toLowerCase();
        return !elementText.contains('ausverkauft') &&
            !elementText.contains('out of stock') &&
            !elementText.contains('sold out');

      case 'sho-cha':
        // For Sho-Cha, check for proper price element
        final priceElement = productElement.querySelector('.product-price');
        if (priceElement != null && priceElement.text.trim().isNotEmpty) {
          final priceText =
              priceElement.text
                  .trim()
                  .replaceAll('\u00A0', ' ') // Replace non-breaking space
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim();
          // Check if price is valid (contains € and is not just "00")
          if (priceText.contains('€') &&
              !priceText.contains('00,00') &&
              priceText != '00') {
            return true;
          }
        }
        return false;

      case 'sazentea':
        // For Sazen Tea, check if we have a valid product name and price
        final nameElement = productElement.querySelector(config.nameSelector);
        if (nameElement == null || nameElement.text.trim().isEmpty) {
          return false;
        }

        final elementText = productElement.text.toLowerCase();
        if (elementText.contains('out of stock') ||
            elementText.contains('sold out') ||
            elementText.contains('unavailable')) {
          return false;
        }

        // Check for price presence as indicator of availability
        final priceElement = productElement.querySelector('.product-price');
        if (priceElement != null) {
          final priceText = priceElement.text.trim();
          return priceText.contains('\$') && !priceText.contains('0.00');
        }

        return false;

      case 'mamecha':
        // For Mamecha, check for product name and availability
        final nameElement = productElement.querySelector(config.nameSelector);
        if (nameElement == null || nameElement.text.trim().isEmpty) {
          return false;
        }

        final elementText = productElement.text.toLowerCase();
        if (elementText.contains('out of stock') ||
            elementText.contains('sold out') ||
            elementText.contains('ausverkauft') ||
            elementText.contains('leider ausverkauft')) {
          return false;
        }

        // Check if "verfügbar" (available) is present
        if (elementText.contains('verfügbar')) {
          return true;
        }

        // Check for price presence as fallback
        final priceElement = productElement.querySelector(
          '.cc-shop-product-price-current',
        );
        if (priceElement != null &&
            priceElement.text.contains('€') &&
            !priceElement.text.contains('0,00')) {
          return true;
        }

        return false;

      case 'enjoyemeri':
        // For Enjoyemeri (Shopify), check for price presence and no out of stock text
        final priceElement = productElement.querySelector(config.priceSelector);
        if (priceElement == null || priceElement.text.trim().isEmpty) {
          return false;
        }

        final elementText = productElement.text.toLowerCase();
        return !elementText.contains('out of stock') &&
            !elementText.contains('sold out');

      case 'poppatea':
        // For Poppatea, check for presence of h3 (product name) and absence of "AUSVERKAUFT"
        final nameElement = productElement.querySelector('h3');
        if (nameElement == null || nameElement.text.trim().isEmpty) {
          return false;
        }

        final elementText = productElement.text;
        return !elementText.contains('AUSVERKAUFT');

      default:
        // Fallback: check for generic stock indicators
        final stockElement = productElement.querySelector(config.stockSelector);
        return stockElement != null;
    }
  }

  /// Cleans and normalizes price strings from different sites
  String _cleanPrice(String rawPrice, String siteKey) {
    if (rawPrice.isEmpty) return rawPrice;

    String cleaned = rawPrice.trim();

    switch (siteKey) {
      case 'marukyu':
        // For Marukyu-Koyamaen, handle multi-currency display
        // Example: "4209.61€8.26£7.15¥68.39" or "100~14.21~€12.21~"
        if (cleaned.contains('€') &&
            cleaned.contains('£') &&
            cleaned.contains('¥')) {
          // Extract individual currencies and format nicely
          final eurMatch = RegExp(r'(\d+[.,]\d+)€').firstMatch(cleaned);
          final gbpMatch = RegExp(r'(\d+[.,]\d+)£').firstMatch(cleaned);
          final jpyMatch = RegExp(r'(\d+[.,]\d+)¥').firstMatch(cleaned);
          final usdMatch = RegExp(r'\$(\d+[.,]\d+)').firstMatch(cleaned);

          List<String> prices = [];
          if (usdMatch != null) prices.add('\$${usdMatch.group(1)}');
          if (eurMatch != null) prices.add('€${eurMatch.group(1)}');
          if (gbpMatch != null) prices.add('£${gbpMatch.group(1)}');
          if (jpyMatch != null) prices.add('¥${jpyMatch.group(1)}');

          return prices.isNotEmpty ? prices.join(' | ') : cleaned;
        }

        // Handle tilde-separated prices: "100~14.21~€12.21~"
        if (cleaned.contains('~')) {
          final parts =
              cleaned.split('~').where((p) => p.trim().isNotEmpty).toList();
          List<String> validPrices = [];

          for (String part in parts) {
            part = part.trim();
            if (RegExp(r'^[\d.,]+$').hasMatch(part)) {
              // Pure number, likely USD
              validPrices.add('\$$part');
            } else if (RegExp(r'^[€£¥\$][\d.,]+$').hasMatch(part)) {
              // Currency symbol at start
              validPrices.add(part);
            } else if (RegExp(r'^[\d.,]+[€£¥]$').hasMatch(part)) {
              // Currency symbol at end
              validPrices.add(part);
            }
          }

          return validPrices.isNotEmpty ? validPrices.join(' | ') : cleaned;
        }
        break;

      case 'sho-cha':
        // For Sho-Cha, handle German Euro formatting
        // Example: "24,00 €" -> "24,00 €"
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

      case 'matcha-karu':
        // For Matcha Kāru, handle German price formatting
        // Example: "AngebotspreisAb 19,00 €" -> "19,00 €"
        cleaned = cleaned.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

        // Remove German text prefixes
        cleaned = cleaned.replaceAll('Angebotspreis', '');
        cleaned = cleaned.replaceAll('Ab ', '');
        cleaned = cleaned.replaceAll('ab ', '');
        cleaned = cleaned.trim();

        // Extract price with Euro symbol and maintain proper spacing
        final priceMatch = RegExp(r'(\d+[.,]\d+)\s*€').firstMatch(cleaned);
        if (priceMatch != null) {
          return '${priceMatch.group(1)} €'; // Add space before Euro symbol
        }

        // Fallback: if it contains a price-like pattern, try to extract it
        final fallbackMatch = RegExp(r'(\d+[.,]\d+)').firstMatch(cleaned);
        if (fallbackMatch != null) {
          return '${fallbackMatch.group(1)} €';
        }

        // Fallback: just clean up the string
        if (cleaned == '00' || cleaned == '0' || cleaned.startsWith('00 ')) {
          return '';
        }
        break;

      case 'yoshien':
        // For Yoshi En, extract price from German format like "Ab 14,90 € 14,90 €"
        cleaned = cleaned.replaceAll('Ab ', '').trim();

        // Extract the first valid price
        final priceMatch = RegExp(r'(\d+[.,]\d+)\s*€').firstMatch(cleaned);
        if (priceMatch != null) {
          return '${priceMatch.group(1)}€';
        }
        break;

      case 'sazentea':
        // For Sazen Tea, extract the first price from formats like "$6.48 / 20 g BOX" or multiple prices
        cleaned = cleaned.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

        // Extract the first price with dollar sign
        final priceMatch = RegExp(r'\$(\d+\.\d+)').firstMatch(cleaned);
        if (priceMatch != null) {
          return '\$${priceMatch.group(1)}';
        }

        // Fallback for other currency formats
        final currencyMatch = RegExp(
          r'([\$€£¥]\s*\d+[.,]\d+)',
        ).firstMatch(cleaned);
        if (currencyMatch != null) {
          return currencyMatch.group(1)!.replaceAll(RegExp(r'\s+'), '');
        }
        break;

      case 'mamecha':
        // For Mamecha, clean up and extract price with € symbol
        cleaned = cleaned.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

        // Look for specific price patterns like "15,20 €" or "9,10 €"
        final priceMatch = RegExp(r'(\d+[.,]\d+)\s*€').firstMatch(cleaned);
        if (priceMatch != null) {
          return '${priceMatch.group(1)}€';
        }

        // Fallback for currency patterns
        final currencyMatch = RegExp(
          r'([\$€£¥]\s*\d+[.,]\d+)',
        ).firstMatch(cleaned);
        if (currencyMatch != null) {
          return currencyMatch.group(1)!.replaceAll(RegExp(r'\s+'), '');
        }
        break;

      case 'poppatea':
        // For Poppatea, handle German Euro formatting
        // Example: "Ab €15,00" -> "15,00 €"
        cleaned =
            cleaned
                .replaceAll('\u00A0', ' ') // Replace non-breaking space
                .replaceAll('\n', ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();

        // Remove "Ab" prefix and extract price
        cleaned = cleaned.replaceAll('Ab ', '').trim();

        // Extract price in German format (€XX,XX or XX,XX €)
        final priceMatch = RegExp(r'€?(\d+,\d{2})\s*€?').firstMatch(cleaned);
        if (priceMatch != null) {
          return '${priceMatch.group(1)} €';
        }

        // Fallback: if it contains € and digits, try to extract
        if (cleaned.contains('€') && RegExp(r'\d').hasMatch(cleaned)) {
          return cleaned;
        }

        return ''; // Invalid price
    }

    // General cleanup for all sites
    cleaned = cleaned.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

    // Remove dollar sign for backward compatibility (except when it's the only currency)
    if (!cleaned.contains('€') &&
        !cleaned.contains('£') &&
        !cleaned.contains('¥')) {
      cleaned = cleaned.replaceAll('\$', '');
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

      case 'Yoshi En':
        return [
          MatchaProduct(
            id: 'yoshien_demo_1',
            name: 'Matcha Tee Okinami Bio',
            normalizedName: 'matcha tee okinami bio',
            site: siteName,
            url: 'https://www.yoshien.com/matcha-okinami-bio-tee.html',
            price: '14,90 €',
            priceValue: 14.90,
            currency: 'EUR',
            isInStock: true,
            lastChecked: now,
            firstSeen: now,
            category: 'Premium Grade',
            description: 'Organic premium matcha from Kagoshima.',
            imageUrl: '',
            weight: 40,
          ),
          MatchaProduct(
            id: 'yoshien_demo_2',
            name: 'Matcha Tee Rikyū Bio',
            normalizedName: 'matcha tee rikyu bio',
            site: siteName,
            url: 'https://www.yoshien.com/matcha-rikyu-bio.html',
            price: '58,90 €',
            priceValue: 58.90,
            currency: 'EUR',
            isInStock: true,
            lastChecked: now,
            firstSeen: now,
            category: 'Contest Grade',
            description: 'Premium ceremonial grade matcha from Uji.',
            imageUrl: '',
            weight: 20,
          ),
        ];

      case 'Matcha Kāru':
        return [
          MatchaProduct(
            id: 'karu_demo_1',
            name: 'Bio Matcha Itsutsu',
            normalizedName: 'bio matcha itsutsu',
            site: siteName,
            url: 'https://matcha-karu.com/products/bio-matcha-itsutsu',
            price: '19,00 €',
            priceValue: 19.00,
            currency: 'EUR',
            isInStock: true,
            lastChecked: now,
            firstSeen: now,
            category: 'Organic Matcha',
            description: 'Certified organic matcha with intense flavor.',
            imageUrl: '',
            weight: 30,
          ),
          MatchaProduct(
            id: 'karu_demo_2',
            name: 'Bio Matcha Hitotsu',
            normalizedName: 'bio matcha hitotsu',
            site: siteName,
            url: 'https://matcha-karu.com/products/bio-matcha-hitotsu',
            price: '35,00 €',
            priceValue: 35.00,
            currency: 'EUR',
            isInStock: false,
            lastChecked: now,
            firstSeen: now,
            category: 'Premium Organic',
            description: 'Top quality organic ceremonial matcha.',
            imageUrl: '',
            weight: 30,
          ),
        ];

      case 'Sho-Cha':
        return [
          MatchaProduct(
            id: 'shocha_demo_1',
            name: 'Premium Matcha Powder',
            normalizedName: 'premium matcha powder',
            site: siteName,
            url: 'https://www.sho-cha.com/products/premium-matcha',
            price: '€25.00',
            priceValue: 25.00,
            currency: 'EUR',
            isInStock: true,
            lastChecked: now,
            firstSeen: now,
            category: 'Premium Grade',
            description: 'High quality matcha for daily enjoyment.',
            imageUrl: '',
            weight: 40,
          ),
        ];

      case 'Sazen Tea':
        return [
          MatchaProduct(
            id: 'sazen_demo_1',
            name: 'Usucha Aya no Mori',
            normalizedName: 'usucha aya no mori',
            site: siteName,
            url:
                'https://www.sazentea.com/en/products/p1602-usucha-aya-no-mori.html',
            price: '\$6.48',
            priceValue: 6.48,
            currency: 'USD',
            isInStock: true,
            lastChecked: now,
            firstSeen: now,
            category: 'Usucha Grade',
            description:
                'Uji matcha for making usucha from Kanbayashi Shunsho.',
            imageUrl: '',
            weight: 20,
          ),
          MatchaProduct(
            id: 'sazen_demo_2',
            name: 'Koicha Matsukazemukashi',
            normalizedName: 'koicha matsukazemukashi',
            site: siteName,
            url:
                'https://www.sazentea.com/en/products/p1596-koicha-matsukazemukashi.html',
            price: '\$9.18',
            priceValue: 9.18,
            currency: 'USD',
            isInStock: true,
            lastChecked: now,
            firstSeen: now,
            category: 'Koicha Grade',
            description:
                'Uji matcha for making koicha from Kanbayashi Shunsho.',
            imageUrl: '',
            weight: 20,
          ),
        ];

      case 'Mamecha':
        return [
          MatchaProduct(
            id: 'mamecha_demo_1',
            name: 'Traditional Matcha Blend',
            normalizedName: 'traditional matcha blend',
            site: siteName,
            url: 'https://www.mamecha.com/products/traditional-matcha',
            price: '¥2,800',
            priceValue: 2800.0,
            currency: 'JPY',
            isInStock: true,
            lastChecked: now,
            firstSeen: now,
            category: 'Traditional Grade',
            description: 'Authentic Japanese matcha blend.',
            imageUrl: '',
            weight: 30,
          ),
        ];

      case 'Emeri':
        return [
          MatchaProduct(
            id: 'enjoyemeri_demo_1',
            name: 'Artisan Matcha Collection',
            normalizedName: 'artisan matcha collection',
            site: siteName,
            url: 'https://www.enjoyemeri.com/products/artisan-matcha',
            price: '\$32.00',
            priceValue: 32.00,
            currency: 'USD',
            isInStock: true,
            lastChecked: now,
            firstSeen: now,
            category: 'Artisan Grade',
            description: 'Handcrafted matcha from select Japanese gardens.',
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
