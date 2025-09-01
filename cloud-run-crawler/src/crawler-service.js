const axios = require('axios');
const cheerio = require('cheerio');
const { v4: uuidv4 } = require('uuid');
const sharp = require('sharp');
const { getStorage } = require('firebase-admin/storage');

// Import specialized crawlers and utilities
const SiteCrawlerFactory = require('./crawlers/site-crawler-factory');
const PriceUtils = require('./utils/price-utils');
const URLUtils = require('./utils/url-utils');
const TextUtils = require('./utils/text-utils');

/**
 * Refactored Cloud-based crawler service for matcha websites
 * Now uses modular architecture with specialized crawlers
 */
class CrawlerService {
  constructor(firestore, logger) {
    this.db = firestore;
    this.logger = logger;
    this.userAgent = 'ZenRadar Bot 1.0 (+https://zenradar.app)';
    this.storage = getStorage();
    
    // Initialize utilities
    this.priceUtils = new PriceUtils();
    this.urlUtils = new URLUtils();
    
    // Site configurations - streamlined version
    this.siteConfigs = {
      'tokichi': {
        name: 'Nakamura Tokichi',
        baseUrl: 'https://global.tokichi.jp',
        categoryUrl: 'https://global.tokichi.jp/collections/matcha',
        productSelector: '.card-wrapper',
        nameSelector: '.card__heading a, .card__content .card__heading',
        priceSelector: '.price__current .price-item--regular, .price .price-item',
        stockSelector: '',
        linkSelector: '.card__heading a, .card__content a',
        imageSelector: '.card__media img, .card__inner img, img[alt*="matcha"]',
        stockKeywords: ['add to cart', 'add to bag', 'buy now'],
        outOfStockKeywords: ['out of stock', 'sold out']
      },
      'marukyu': {
        name: 'Marukyu-Koyamaen',
        baseUrl: 'https://www.marukyu-koyamaen.co.jp',
        categoryUrl: 'https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha?currency=USD',
        productSelector: '.item, .product-item, .product',
        nameSelector: '.item-name, .product-name, .name, h3',
        priceSelector: '.price, .item-price, .cost',
        stockSelector: '.cart-form button:not([disabled]), .add-to-cart:not(.disabled)',
        linkSelector: 'a, .item-link',
        imageSelector: '.item-image img, .product-image img, img[src*="product"]',
        stockKeywords: ['add to cart', 'in stock', 'available'],
        outOfStockKeywords: ['out of stock', 'sold out', 'unavailable']
      },
      'ippodo': {
        name: 'Ippodo Tea',
        baseUrl: 'https://global.ippodo-tea.co.jp',
        categoryUrl: 'https://global.ippodo-tea.co.jp/collections/matcha',
        productSelector: '.m-product-card',
        nameSelector: '.m-product-card__name, .m-product-card__body a',
        priceSelector: '.m-product-card__price',
        stockSelector: '.out-of-stock',
        linkSelector: 'a[href*="/products/"]',
        imageSelector: '.m-product-card__image img, .product-card__media img',
        stockKeywords: ['add to cart', 'buy now', 'purchase'],
        outOfStockKeywords: ['out of stock', 'sold out']
      },
      'sho-cha': {
        name: 'Sho-Cha',
        baseUrl: 'https://www.sho-cha.com',
        categoryUrl: 'https://www.sho-cha.com/teeshop',
        productSelector: 'h1',
        nameSelector: 'h1',
        priceSelector: '.price, .cost, .amount, .money',
        stockSelector: '.add-to-cart, .cart-button, .shop-button',
        linkSelector: 'a[href*="/teeshop/"]',
        imageSelector: '.product-image img, .item-image img, img[src*="product"], img[src*="tea"], img[src*="matcha"]',
        stockKeywords: ['add to cart', 'kaufen', 'in den warenkorb', 'verfügbar'],
        outOfStockKeywords: ['ausverkauft', 'sold out', 'nicht verfügbar'],
        requiresSpecializedCrawler: true
      },
      'poppatea': {
        name: 'Poppatea',
        baseUrl: 'https://poppatea.com',
        categoryUrl: 'https://poppatea.com/collections/all',
        productSelector: '.card, .product-card, .grid-item',
        nameSelector: 'h3, .card-title, [data-product-title], .product-title',
        priceSelector: '.price, .money',
        stockSelector: '.add-to-cart, .cart-button',
        linkSelector: 'a',
        imageSelector: 'img, .card-image img, .product-image img, img[src*="product"], img[src*="cdn/shop"]',
        stockKeywords: ['add to cart', 'lägg i varukorg', 'köp'],
        outOfStockKeywords: ['slutsåld', 'ej i lager', 'sold out', 'notify me'],
        requiresSpecializedCrawler: true
      },
      'matcha-karu': {
        name: 'Matcha Kāru',
        baseUrl: 'https://matcha-karu.com',
        categoryUrl: 'https://matcha-karu.com/collections/matcha-tee',
        productSelector: '.product-item',
        nameSelector: 'a[href*="/products/"] img[alt], a[href*="/products/"]:nth-of-type(2)',
        priceSelector: '.price, .price__current, .price-item',
        stockSelector: '.product-form, .add-to-cart:not(.disabled)',
        linkSelector: 'a[href*="/products/"]:first',
        imageSelector: '.product-item__aspect-ratio img, .product-item__image img, img[src*="products/"]',
        stockKeywords: ['add to cart', 'in den warenkorb', 'kaufen', 'angebotspreis'],
        outOfStockKeywords: ['ausverkauft', 'nicht verfügbar', 'sold out']
      },
      'yoshien': {
        name: 'Yoshi En',
        baseUrl: 'https://www.marukyu-koyamaen.co.jp',
        categoryUrl: 'https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha?currency=USD',
        productSelector: '.product',
        nameSelector: '.product-name, .item-name, h3',
        priceSelector: '.price, .item-price, .cost',
        stockSelector: '.cart-form button:not([disabled]), .add-to-cart:not(.disabled)',
        linkSelector: 'a, .item-link',
        imageSelector: '.product-image img, .item-image img, img[src*="product"]',
        stockKeywords: ['add to cart', 'in stock', 'available'],
        outOfStockKeywords: ['out of stock', 'sold out', 'unavailable']
      },
      'sazentea': {
        name: 'Sazen Tea',
        baseUrl: 'https://www.sazentea.com',
        categoryUrl: 'https://www.sazentea.com/en/products/c21-matcha',
        productSelector: '.product',
        nameSelector: '.product-name',
        priceSelector: '.product-price',
        stockSelector: '.product-price',
        linkSelector: 'a[href*="/products/"]',
        imageSelector: 'img[src*="/content/products/"], .product-image-img, img[alt*="Matcha"]:not([alt*="Best"]):not([alt*="Selling"]):not([alt*="Specialty"]):not([alt*="Extra"])',
        stockKeywords: ['add to cart', 'in stock', 'available'],
        outOfStockKeywords: ['out of stock', 'sold out', 'unavailable']
      },
      'enjoyemeri': {
        name: 'Emeri',
        baseUrl: 'https://enjoyemeri.com',
        categoryUrl: 'https://www.enjoyemeri.com/collections/shop-all',
        productSelector: '.product-card',
        nameSelector: 'h3, .product-title',
        priceSelector: '.price',
        stockSelector: '.price',
        linkSelector: 'a',
        imageSelector: '.product-media__image, .product-card__image img',
        stockKeywords: ['add to cart', 'buy now', 'purchase'],
        outOfStockKeywords: ['out of stock', 'sold out']
      },
      'horiishichimeien': {
        name: 'Horiishichimeien',
        baseUrl: 'https://horiishichimeien.com',
        categoryUrl: 'https://horiishichimeien.com/en/collections/all?selected=%E6%8A%B9%E8%8C%B6',
        productSelector: '.grid__item',
        nameSelector: 'a[href*="/products/"] span.visually-hidden, .card__heading, .product-title',
        priceSelector: '.price__regular .money, .price .money, .price-item--regular',
        stockSelector: '.product-form__buttons, .product-form, form[action="/cart/add"], button[name="add"]',
        linkSelector: 'a[href*="/products/"]',
        imageSelector: '.grid-view-item__image, .lazyload, img[src*="products/"], .product-image img',
        stockKeywords: ['add to cart', 'buy now', 'purchase', 'add to bag', 'カートに入れる'],
        outOfStockKeywords: ['sold out', 'unavailable', '売り切れ', 'out of stock'],
        currencyConversion: {
          from: 'JPY',
          to: 'EUR',
          rate: 0.0058
        }
      }
    };

    // Request configuration
    this.requestConfig = {
      timeout: 30000,
      headers: {
        'User-Agent': this.userAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache'
      }
    };
  }

  /**
   * Main crawl function - processes specified sites or all sites
   */
  async crawlSites(sitesToCrawl = []) {
    const startTime = Date.now();
    const results = {
      totalProducts: 0,
      stockUpdates: 0,
      sitesProcessed: 0,
      errors: [],
      sites: {}
    };

    // Determine which sites to crawl
    const targetSites = sitesToCrawl.length > 0 
      ? sitesToCrawl.filter(site => this.siteConfigs[site])
      : Object.keys(this.siteConfigs);

    this.logger.info('Starting crawl operation', {
      sitesToCrawl: targetSites,
      totalSites: targetSites.length
    });

    // Process sites in parallel (with concurrency limit)
    const concurrencyLimit = 3;
    const siteChunks = this.chunkArray(targetSites, concurrencyLimit);

    for (const chunk of siteChunks) {
      const promises = chunk.map(siteKey => this.crawlSite(siteKey));
      const chunkResults = await Promise.allSettled(promises);

      for (let i = 0; i < chunkResults.length; i++) {
        const siteKey = chunk[i];
        const result = chunkResults[i];

        if (result.status === 'fulfilled') {
          const siteData = result.value;
          results.sites[siteKey] = siteData;
          results.totalProducts += siteData.products.length;
          results.stockUpdates += siteData.stockUpdates;
          results.sitesProcessed++;

          this.logger.info('Site crawl completed', {
            site: siteKey,
            products: siteData.products.length,
            stockUpdates: siteData.stockUpdates,
            duration: siteData.duration
          });
        } else {
          const error = result.reason;
          results.errors.push({
            site: siteKey,
            error: error.message,
            timestamp: new Date().toISOString()
          });

          this.logger.error('Site crawl failed', {
            site: siteKey,
            error: error.message
          });
        }
      }
    }

    const totalDuration = Date.now() - startTime;
    
    this.logger.info('Crawl operation completed', {
      totalProducts: results.totalProducts,
      stockUpdates: results.stockUpdates,
      sitesProcessed: results.sitesProcessed,
      errors: results.errors.length,
      duration: `${totalDuration}ms`
    });

    return results;
  }

  /**
   * Crawl a single site using specialized crawlers when available
   */
  async crawlSite(siteKey) {
    const startTime = Date.now();
    const config = this.siteConfigs[siteKey];
    
    if (!config) {
      throw new Error(`Site configuration not found: ${siteKey}`);
    }

    this.logger.info('Starting site crawl', { site: siteKey, url: config.categoryUrl });

    try {
      // Check if we have a specialized crawler for this site
      if (SiteCrawlerFactory.hasSpecializedCrawler(siteKey)) {
        this.logger.info('Using specialized crawler', { site: siteKey });
        const specializedCrawler = SiteCrawlerFactory.getCrawler(siteKey, this.logger);
        
        const specializedResult = await specializedCrawler.crawl(config.categoryUrl, config);
        
        // Process the specialized results
        return await this.processSpecializedCrawlResults(siteKey, specializedResult, startTime);
      } else {
        // Use generic crawler
        this.logger.info('Using generic crawler', { site: siteKey });
        return await this.crawlSiteGeneric(siteKey, config, startTime);
      }
    } catch (error) {
      this.logger.error('Site crawl failed', {
        site: siteKey,
        error: error.message,
        stack: error.stack
      });
      throw error;
    }
  }

  /**
   * Process results from specialized crawlers
   */
  async processSpecializedCrawlResults(siteKey, specializedResult, startTime) {
    const products = [];
    let stockUpdates = 0;

    this.logger.info('Processing specialized crawl results', {
      site: siteKey,
      rawProducts: specializedResult.products.length
    });

    // Process each product from specialized crawler
    for (const productData of specializedResult.products) {
      try {
        // Convert specialized crawler data to our standard format
        const standardProduct = await this.standardizeProductData(productData, siteKey);
        
        if (standardProduct) {
          // Save to database and check for stock updates
          const stockChanged = await this.saveProduct(standardProduct, siteKey);
          if (stockChanged) {
            stockUpdates++;
          }
          
          products.push(standardProduct);
        }
      } catch (error) {
        this.logger.error('Failed to process specialized product', {
          site: siteKey,
          productTitle: productData.name || 'Unknown',
          error: error.message
        });
      }
    }

    const duration = Date.now() - startTime;
    
    return {
      products,
      stockUpdates,
      duration: `${duration}ms`,
      errors: specializedResult.errors || []
    };
  }

  /**
   * Generic crawler for sites without specialized implementation
   */
  async crawlSiteGeneric(siteKey, config, startTime) {
    // Fetch the category page
    const response = await axios.get(config.categoryUrl, this.requestConfig);
    const $ = cheerio.load(response.data);

    const products = [];
    let stockUpdates = 0;

    // Find all product containers
    const productElements = $(config.productSelector);
    
    this.logger.info('Product containers found', {
      site: siteKey,
      containersFound: productElements.length
    });

    // Process each product container
    for (let i = 0; i < productElements.length; i++) {
      const productElement = $(productElements[i]);
      
      try {
        const productData = await this.extractGenericProductData($, productElement, config, siteKey);
        
        if (productData && productData.name && productData.name.trim()) {
          // Save to database and check for stock updates
          const stockChanged = await this.saveProduct(productData, siteKey);
          if (stockChanged) {
            stockUpdates++;
          }
          
          products.push(productData);
        }
      } catch (error) {
        this.logger.error('Failed to process generic product', {
          site: siteKey,
          productIndex: i,
          error: error.message
        });
      }
    }

    const duration = Date.now() - startTime;
    
    return {
      products,
      stockUpdates,
      duration: `${duration}ms`,
      errors: []
    };
  }

  /**
   * Extract product data using generic selectors
   */
  async extractGenericProductData($, productElement, config, siteKey) {
    // Extract basic information
    const name = this.extractText($, productElement, config.nameSelector);
    const price = this.extractText($, productElement, config.priceSelector);
    const link = this.extractLink($, productElement, config.linkSelector, config.baseUrl);
    const imageUrl = this.extractImageUrl($, productElement, config.imageSelector);
    
    // Determine stock status
    const stockStatus = this.determineStockStatus($, productElement, config);
    
    // Clean and process the data
    const cleanedPrice = this.priceUtils.cleanPriceBySite(price, siteKey);
    const priceValue = this.priceUtils.extractPriceValue(cleanedPrice);
    
    return {
      id: uuidv4(),
      name: TextUtils.cleanProductTitle(name),
      price: cleanedPrice,
      priceValue: priceValue,
      url: this.urlUtils.cleanUrl(link),
      imageUrl: this.urlUtils.cleanUrl(imageUrl),
      inStock: stockStatus === 'in_stock',
      site: config.name,
      siteKey: siteKey,
      lastUpdated: new Date().toISOString(),
      category: TextUtils.extractCategory(name),
      weight: TextUtils.extractWeight(name)
    };
  }

  /**
   * Standardize product data from specialized crawlers
   */
  async standardizeProductData(productData, siteKey) {
    const config = this.siteConfigs[siteKey];
    
    return {
      id: productData.id || uuidv4(),
      name: TextUtils.cleanProductTitle(productData.name),
      price: productData.price || '',
      priceValue: productData.priceValue || null,
      url: this.urlUtils.cleanUrl(productData.url),
      imageUrl: this.urlUtils.cleanUrl(productData.imageUrl),
      inStock: productData.inStock !== false,
      site: config.name,
      siteKey: siteKey,
      lastUpdated: new Date().toISOString(),
      category: productData.category || TextUtils.extractCategory(productData.name),
      weight: productData.weight || TextUtils.extractWeight(productData.name),
      variants: productData.variants || []
    };
  }

  /**
   * Extract text content using selector
   */
  extractText($, element, selector) {
    if (!selector) return '';
    
    const targetElement = element.find(selector).first();
    if (targetElement.length > 0) {
      return TextUtils.extractTextContent($, targetElement);
    }
    
    return '';
  }

  /**
   * Extract link URL using selector
   */
  extractLink($, element, selector, baseUrl) {
    if (!selector) return '';
    
    const linkElement = element.find(selector).first();
    if (linkElement.length > 0) {
      const href = linkElement.attr('href');
      if (href) {
        return this.urlUtils.buildAbsoluteUrl(href, baseUrl);
      }
    }
    
    return '';
  }

  /**
   * Extract image URL using selector
   */
  extractImageUrl($, element, selector) {
    if (!selector) return '';
    
    const imgElement = element.find(selector).first();
    if (imgElement.length > 0) {
      const src = imgElement.attr('src') || imgElement.attr('data-src') || imgElement.attr('data-lazy');
      if (src) {
        return src.startsWith('//') ? 'https:' + src : src;
      }
    }
    
    return '';
  }

  /**
   * Determine stock status based on page content
   */
  determineStockStatus($, element, config) {
    // Check for stock selector
    if (config.stockSelector) {
      const stockElement = element.find(config.stockSelector);
      if (stockElement.length > 0) {
        const stockText = TextUtils.extractTextContent($, stockElement);
        return TextUtils.extractStockStatus(stockText);
      }
    }
    
    // Check entire element text for stock keywords
    const elementText = TextUtils.extractTextContent($, element);
    return TextUtils.extractStockStatus(elementText);
  }

  /**
   * Save product to database and detect stock changes
   */
  async saveProduct(productData, siteKey) {
    try {
      // Generate unique product identifier
      const productIdentifier = this.urlUtils.generateProductIdentifier(
        productData.url, 
        productData.name, 
        siteKey
      );
      
      // Check if product exists
      const existingProduct = await this.getExistingProduct(productIdentifier, siteKey);
      
      // Detect stock changes
      let stockChanged = false;
      if (existingProduct && existingProduct.inStock !== productData.inStock) {
        stockChanged = true;
        this.logger.info('Stock status changed', {
          product: productData.name,
          site: siteKey,
          oldStock: existingProduct.inStock,
          newStock: productData.inStock
        });
      }
      
      // Save product data
      const docRef = this.db.collection('products').doc(productIdentifier);
      await docRef.set({
        ...productData,
        productIdentifier,
        lastCrawled: new Date()
      }, { merge: true });
      
      return stockChanged;
    } catch (error) {
      this.logger.error('Failed to save product', {
        product: productData.name,
        site: siteKey,
        error: error.message
      });
      return false;
    }
  }

  /**
   * Get existing product from database
   */
  async getExistingProduct(productIdentifier, siteKey) {
    try {
      const docRef = this.db.collection('products').doc(productIdentifier);
      const doc = await docRef.get();
      return doc.exists ? doc.data() : null;
    } catch (error) {
      this.logger.error('Failed to get existing product', {
        productIdentifier,
        siteKey,
        error: error.message
      });
      return null;
    }
  }

  /**
   * Utility function to split array into chunks
   */
  chunkArray(array, size) {
    const chunks = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }
}

module.exports = CrawlerService;
