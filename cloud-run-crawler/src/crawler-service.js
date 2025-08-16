const axios = require('axios');
const cheerio = require('cheerio');
const { v4: uuidv4 } = require('uuid');

/**
 * Cloud-based crawler service for matcha websites
 * Optimized for parallel processing and delta crawling
 */
class CrawlerService {
  constructor(firestore, logger) {
    this.db = firestore;
    this.logger = logger;
    this.userAgent = 'ZenRadar Bot 1.0 (+https://zenradar.app)';
    
    // Site configurations - complete list matching Flutter app
    this.siteConfigs = {
      'tokichi': {
        name: 'Nakamura Tokichi',
        baseUrl: 'https://global.tokichi.jp',
        categoryUrl: 'https://global.tokichi.jp/collections/matcha',
        productSelector: '.card-wrapper .card__heading a, .card__content a',
        nameSelector: '.card__heading, .product__title, h1.product__title',
        priceSelector: '.price__current .price-item--regular, .price .price-item, .product__price',
        stockSelector: '.btn--add-to-cart, .product-form__buttons button',
        stockKeywords: ['add to cart', 'add to bag', 'buy now'],
        outOfStockKeywords: ['out of stock', 'sold out']
      },
      'marukyu': {
        name: 'Marukyu-Koyamaen',
        baseUrl: 'https://www.marukyu-koyamaen.co.jp',
        categoryUrl: 'https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha?currency=USD',
        productSelector: '.item, .product-item, .product',
        nameSelector: '.item-name, .product-name, .name, h3, h1',
        priceSelector: '.price, .item-price, .cost',
        stockSelector: '.cart-form button:not([disabled]), .add-to-cart:not(.disabled)',
        stockKeywords: ['add to cart', 'in stock', 'available'],
        outOfStockKeywords: ['out of stock', 'sold out', 'unavailable']
      },
      'ippodo': {
        name: 'Ippodo Tea',
        baseUrl: 'https://global.ippodo-tea.co.jp',
        categoryUrl: 'https://global.ippodo-tea.co.jp/collections/matcha',
        productSelector: '.m-product-card, .product-card',
        nameSelector: '.m-product-card__name, .m-product-card__body a, .product-card__title, h1',
        priceSelector: '.m-product-card__price, .product__price, .price',
        stockSelector: '.btn--add-to-cart, .product-form__buttons',
        stockKeywords: ['add to cart', 'buy now', 'purchase'],
        outOfStockKeywords: ['out of stock', 'sold out']
      },
      'yoshien': {
        name: 'Yoshi En',
        baseUrl: 'https://www.yoshien.com',
        categoryUrl: 'https://www.yoshien.com/matcha/matcha-tee/',
        productSelector: '.cs-product-tile',
        nameSelector: '.cs-product-tile__name, .cs-product-tile__name-link, h1',
        priceSelector: '.cs-product-tile__price, .product__price',
        stockSelector: 'a[href*="matcha"], .add-to-cart',
        stockKeywords: ['add to cart', 'in stock', 'verfügbar'],
        outOfStockKeywords: ['ausverkauft', 'out of stock', 'sold out']
      },
      'matcha-karu': {
        name: 'Matcha Kāru',
        baseUrl: 'https://matcha-karu.com',
        categoryUrl: 'https://matcha-karu.com/collections/matcha-tee',
        productSelector: '.product-item',
        nameSelector: '.product-item-meta__title, .product-item__info a, h1',
        priceSelector: 'span.price, .price:not(.price--block), .product__price',
        stockSelector: '.price, .add-to-cart',
        stockKeywords: ['add to cart', 'in den warenkorb', 'kaufen'],
        outOfStockKeywords: ['ausverkauft', 'nicht verfügbar', 'sold out']
      },
      'sho-cha': {
        name: 'Sho-Cha',
        baseUrl: 'https://www.sho-cha.com',
        categoryUrl: 'https://www.sho-cha.com/teeshop',
        productSelector: '.ProductList-item',
        nameSelector: '.ProductList-title, .ProductList-title a, h1',
        priceSelector: '.product-price, .sqs-money-native, .ProductList-price',
        stockSelector: '.product-price, .add-to-cart',
        stockKeywords: ['add to cart', 'kaufen', 'in den warenkorb'],
        outOfStockKeywords: ['ausverkauft', 'sold out', 'nicht verfügbar']
      },
      'sazentea': {
        name: 'Sazen Tea',
        baseUrl: 'https://www.sazentea.com',
        categoryUrl: 'https://www.sazentea.com/en/products/c21-matcha',
        productSelector: '.product',
        nameSelector: '.product-name, h1',
        priceSelector: '.product-price',
        stockSelector: '.product-price, .add-to-cart',
        stockKeywords: ['add to cart', 'in stock', 'available'],
        outOfStockKeywords: ['out of stock', 'sold out', 'unavailable']
      },
      'mamecha': {
        name: 'Mamecha',
        baseUrl: 'https://www.mamecha.de',
        categoryUrl: 'https://www.mamecha.de/collections/alle-tees',
        productSelector: '.product-item',
        nameSelector: '.product-item__title a, h1',
        priceSelector: '.price-item--regular, .price-item--sale, .product__price',
        stockSelector: '.product-item__title a, .add-to-cart',
        stockKeywords: ['add to cart', 'in den warenkorb', 'verfügbar'],
        outOfStockKeywords: ['ausverkauft', 'nicht auf lager', 'sold out']
      },
      'enjoyemeri': {
        name: 'Emeri',
        baseUrl: 'https://www.enjoyemeri.com',
        categoryUrl: 'https://www.enjoyemeri.com/collections/shop-all',
        productSelector: '.product-card',
        nameSelector: 'h3, .product__title, h1',
        priceSelector: '.price, .product__price',
        stockSelector: '.price, .add-to-cart',
        stockKeywords: ['add to cart', 'buy now', 'purchase'],
        outOfStockKeywords: ['out of stock', 'sold out']
      },
      'poppatea': {
        name: 'Poppatea',
        baseUrl: 'https://poppatea.com',
        categoryUrl: 'https://poppatea.com/de-de/collections/all-teas?filter.p.m.custom.tea_type=Matcha',
        productSelector: '.card__container',
        nameSelector: 'h3, .product__title, h1',
        priceSelector: '.price__regular, .product__price',
        stockSelector: 'h3, .add-to-cart',
        stockKeywords: ['add to cart', 'in den warenkorb', 'kaufen'],
        outOfStockKeywords: ['ausverkauft', 'nicht verfügbar', 'sold out']
      },
      'horiishichimeien': {
        name: 'Horiishichimeien',
        baseUrl: 'https://horiishichimeien.com',
        categoryUrl: 'https://horiishichimeien.com/en/collections/all?selected=%E6%8A%B9%E8%8C%B6',
        productSelector: '.product-card, .product-item, .grid-product',
        nameSelector: '.product-card__title, .product__title, h1, .grid-product__title',
        priceSelector: '.product-card__price, .product__price, .price, .grid-product__price',
        stockSelector: '.btn--add-to-cart, .add-to-cart, .product-form__buttons',
        stockKeywords: ['add to cart', 'buy now', 'purchase', 'add to bag'],
        outOfStockKeywords: ['out of stock', 'sold out', 'unavailable', '売り切れ']
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
   * Crawl a single site
   */
  async crawlSite(siteKey) {
    const startTime = Date.now();
    const config = this.siteConfigs[siteKey];
    
    if (!config) {
      throw new Error(`Site configuration not found: ${siteKey}`);
    }

    this.logger.info('Starting site crawl', { site: siteKey, url: config.categoryUrl });

    try {
      // Fetch the category page
      const response = await axios.get(config.categoryUrl, this.requestConfig);
      const $ = cheerio.load(response.data);

      // Extract product links
      const productLinks = [];
      $(config.productSelector).each((index, element) => {
        const href = $(element).attr('href');
        if (href) {
          const fullUrl = href.startsWith('http') ? href : config.baseUrl + href;
          productLinks.push(fullUrl);
        }
      });

      this.logger.info('Product links extracted', {
        site: siteKey,
        linksFound: productLinks.length
      });

      // Process products in smaller batches
      const products = [];
      const batchSize = 5;
      let stockUpdates = 0;

      for (let i = 0; i < productLinks.length; i += batchSize) {
        const batch = productLinks.slice(i, i + batchSize);
        const batchPromises = batch.map(url => this.extractProductData(url, siteKey, config));
        const batchResults = await Promise.allSettled(batchPromises);

        for (const result of batchResults) {
          if (result.status === 'fulfilled' && result.value) {
            const product = result.value;
            products.push(product);

            // Save to Firestore and check for stock changes
            const wasUpdated = await this.saveProduct(product);
            if (wasUpdated) stockUpdates++;
          }
        }

        // Small delay between batches to be respectful
        if (i + batchSize < productLinks.length) {
          await this.delay(1000);
        }
      }

      const duration = Date.now() - startTime;

      return {
        site: siteKey,
        products,
        stockUpdates,
        duration,
        timestamp: new Date().toISOString()
      };

    } catch (error) {
      this.logger.error('Site crawl error', {
        site: siteKey,
        error: error.message,
        url: config.categoryUrl
      });
      throw error;
    }
  }

  /**
   * Extract product data from a product page
   */
  async extractProductData(url, siteKey, config) {
    try {
      const response = await axios.get(url, {
        ...this.requestConfig,
        timeout: 20000 // Reduced timeout for individual products
      });
      const $ = cheerio.load(response.data);

      // Extract product name
      let name = $(config.nameSelector).first().text().trim();
      if (!name) {
        name = $('h1').first().text().trim();
      }
      
      // Clean up name (remove extra whitespace, newlines)
      name = name.replace(/\s+/g, ' ').trim();

      // Extract price
      let price = $(config.priceSelector).first().text().trim();
      if (!price) {
        price = $('.price, .product-price, [class*="price"]').first().text().trim();
      }

      // Clean price based on site-specific logic
      price = this.cleanPriceBySite(price, siteKey);

      // Determine stock status using site-specific logic
      const isInStock = this.determineStockStatus($, config, siteKey);

      // Generate product ID
      const productId = this.generateProductId(url, name, siteKey);

      const product = {
        id: productId,
        name: name || 'Unknown Product',
        site: siteKey,
        siteName: config.name,
        price: price,
        originalPrice: price,
        url: url,
        isInStock,
        category: 'matcha',
        lastChecked: new Date(),
        lastUpdated: new Date(),
        isDiscontinued: false,
        crawlSource: 'cloud-run'
      };

      this.logger.info('Product extracted', {
        site: siteKey,
        name: product.name,
        price: product.price,
        inStock: product.isInStock,
        url: url
      });

      return product;

    } catch (error) {
      this.logger.warn('Failed to extract product data', {
        url,
        site: siteKey,
        error: error.message
      });
      return null;
    }
  }

  /**
   * Determine stock status using site-specific logic
   */
  determineStockStatus($, config, siteKey) {
    const pageText = $('body').text().toLowerCase();

    switch (siteKey) {
      case 'tokichi':
        // For Tokichi, check if "Out of stock" text is present
        return !pageText.includes('out of stock') && !pageText.includes('sold out');

      case 'ippodo':
        // For Ippodo, check for .out-of-stock class
        const outOfStockElement = $('.out-of-stock');
        return outOfStockElement.length === 0;

      case 'marukyu':
        // For Marukyu, check for stock classes and buttons
        if ($('.instock').length > 0) return true;
        if ($('.outofstock').length > 0) return false;
        // Check for add to cart button
        const addToCartBtn = $('.cart-form button:not([disabled]), .add-to-cart:not(.disabled)');
        return addToCartBtn.length > 0;

      case 'yoshien':
        // For Yoshi En, check for out-of-stock class and German text
        if ($('.cs-product-tile--out-of-stock').length > 0) return false;
        if (pageText.includes('ausverkauft') || pageText.includes('nicht verfügbar')) return false;
        return true;

      case 'matcha-karu':
        // For Matcha Kāru, check if price is present and no out-of-stock text
        const priceElement = $(config.priceSelector);
        if (priceElement.length === 0 || !priceElement.text().trim()) return false;
        return !pageText.includes('ausverkauft') && !pageText.includes('nicht verfügbar');

      case 'sho-cha':
        // For Sho-Cha, check for sold-out CSS class and German text
        if ($('.sold-out').length > 0) return false;
        if (pageText.includes('ausverkauft') || pageText.includes('nicht verfügbar')) return false;
        const priceEl = $(config.priceSelector);
        return priceEl.length > 0 && priceEl.text().trim() !== '';

      case 'sazentea':
        // For Sazen Tea, check for price presence and stock indicators
        if (pageText.includes('out of stock') || pageText.includes('sold out')) return false;
        const priceExists = $(config.priceSelector).length > 0;
        return priceExists;

      case 'mamecha':
        // For Mamecha, check German availability text
        if (pageText.includes('out of stock') || pageText.includes('ausverkauft')) return false;
        if (pageText.includes('verfügbar')) return true;
        const pricePresent = $(config.priceSelector).length > 0;
        return pricePresent;

      case 'enjoyemeri':
        // For Enjoyemeri (Shopify), check for price and no out of stock text
        const priceAvailable = $(config.priceSelector).length > 0;
        return priceAvailable && !pageText.includes('out of stock') && !pageText.includes('sold out');

      case 'poppatea':
        // For Poppatea, check for German out-of-stock indicators
        if (pageText.includes('ausverkauft') || pageText.includes('nicht verfügbar') || 
            pageText.includes('sold out') || pageText.includes('out of stock')) return false;
        return true;

      case 'horiishichimeien':
        // For Horiishichimeien, check for Japanese and English out-of-stock indicators
        if (pageText.includes('売り切れ') || pageText.includes('out of stock') || 
            pageText.includes('sold out') || pageText.includes('unavailable')) return false;
        // Check for add to cart button or similar indicators
        const addToCartExists = $(config.stockSelector).length > 0;
        return addToCartExists;

      default:
        // Fallback: check for stock keywords vs out-of-stock keywords
        const hasStockKeywords = config.stockKeywords.some(keyword => 
          pageText.includes(keyword.toLowerCase())
        );
        const hasOutOfStockKeywords = config.outOfStockKeywords.some(keyword => 
          pageText.includes(keyword.toLowerCase())
        );
        
        if (hasOutOfStockKeywords) return false;
        if (hasStockKeywords) return true;
        
        // Final fallback: check if price is present
        return $(config.priceSelector).length > 0;
    }
  }

  /**
   * Clean price string based on site-specific logic
   */
  cleanPriceBySite(rawPrice, siteKey) {
    if (!rawPrice) return '';

    let cleaned = rawPrice.trim();

    switch (siteKey) {
      case 'marukyu':
        // Handle multi-currency display: "4209.61€8.26£7.15¥68.39"
        if (cleaned.includes('€') && cleaned.includes('£')) {
          const euroMatch = cleaned.match(/(\d+(?:\.\d{2})?)\s*€/);
          if (euroMatch) return euroMatch[1] + ' €';
        }
        // Handle tilde-separated prices: "100~14.21~€12.21~"
        if (cleaned.includes('~')) {
          const euroMatch = cleaned.match(/€([0-9.,]+)~/);
          if (euroMatch) return euroMatch[1] + ' €';
        }
        break;

      case 'sho-cha':
        // Handle German Euro formatting: "24,00 €"
        cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
        const euroPriceMatch = cleaned.match(/(\d+(?:,\d{2})?\s*€)/);
        if (euroPriceMatch) return euroPriceMatch[1];
        
        // Try USD format
        const usdPriceMatch = cleaned.match(/\$(\d+(?:\.\d{2})?)/);
        if (usdPriceMatch) return usdPriceMatch[1] + ' USD';
        break;

      case 'matcha-karu':
        // Handle German price formatting: "AngebotspreisAb 19,00 €"
        cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
        cleaned = cleaned.replace(/Angebotspreis/g, '');
        cleaned = cleaned.replace(/Ab /g, '');
        cleaned = cleaned.replace(/ab /g, '');
        
        const matchaKaruMatch = cleaned.match(/(\d+,\d{2}\s*€)/);
        if (matchaKaruMatch) return matchaKaruMatch[1];
        break;

      case 'yoshien':
      case 'sazentea':
      case 'mamecha':
      case 'poppatea':
      case 'horiishichimeien':
        // Standard cleanup for these sites
        cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
        break;
    }

    // General cleanup
    cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
    
    // Extract price pattern (number with currency)
    const priceMatch = cleaned.match(/(\d+[.,]\d{2}\s*[€$¥£]|\d+\s*[€$¥£])/);
    if (priceMatch) {
      return priceMatch[1];
    }

    // Fallback: remove non-price characters
    return cleaned.replace(/[^\d.,€$¥£\s]/g, '').trim();
  }

  /**
   * Save product to Firestore and detect stock changes
   */
  async saveProduct(product) {
    try {
      const productRef = this.db.collection('products').doc(product.id);
      const existingDoc = await productRef.get();
      
      let wasUpdated = false;

      if (existingDoc.exists) {
        const existingData = existingDoc.data();
        
        // Check for stock status change
        if (existingData.isInStock !== product.isInStock) {
          wasUpdated = true;
          
          // Log stock change
          this.logger.info('Stock status changed', {
            productId: product.id,
            name: product.name,
            site: product.site,
            previousStock: existingData.isInStock,
            newStock: product.isInStock
          });

          // Add to stock history
          await this.db.collection('stock_history').add({
            productId: product.id,
            productName: product.name,
            site: product.site,
            isInStock: product.isInStock,
            previousStatus: existingData.isInStock,
            timestamp: new Date(),
            crawlSource: 'cloud-run'
          });
        }

        // Update existing product
        await productRef.update({
          ...product,
          lastChecked: new Date(),
          lastUpdated: wasUpdated ? new Date() : existingData.lastUpdated
        });
      } else {
        // New product
        await productRef.set(product);
        wasUpdated = true;
        
        this.logger.info('New product added', {
          productId: product.id,
          name: product.name,
          site: product.site
        });
      }

      return wasUpdated;

    } catch (error) {
      this.logger.error('Failed to save product', {
        productId: product.id,
        error: error.message
      });
      return false;
    }
  }

  /**
   * Generate consistent product ID
   */
  generateProductId(url, name, siteKey) {
    const urlPart = url.split('/').pop() || '';
    const namePart = name.toLowerCase().replace(/[^a-z0-9]/g, '').substring(0, 20);
    const sitePrefix = siteKey ? `${siteKey}_` : '';
    return `${sitePrefix}${urlPart}_${namePart}`.replace(/[^a-z0-9_]/g, '');
  }

  /**
   * Clean price string
   */
  cleanPrice(priceStr) {
    if (!priceStr) return '';
    return priceStr.replace(/[^\d.,€$¥£]/g, '').trim();
  }

  /**
   * Utility function to chunk array
   */
  chunkArray(array, size) {
    const chunks = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }

  /**
   * Utility function for delays
   */
  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

module.exports = CrawlerService;
