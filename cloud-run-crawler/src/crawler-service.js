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
        productSelector: '.card-wrapper',
        nameSelector: '.card__heading a, .card__content .card__heading',
        priceSelector: '.price__current .price-item--regular, .price .price-item',
        stockSelector: '', // Determine stock by absence of "Out of stock" text
        linkSelector: '.card__heading a, .card__content a',
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
        stockSelector: '.out-of-stock', // Products are out of stock if this element exists
        linkSelector: 'a[href*="/products/"]',
        stockKeywords: ['add to cart', 'buy now', 'purchase'],
        outOfStockKeywords: ['out of stock', 'sold out']
      },
      'yoshien': {
        name: 'Yoshi En',
        baseUrl: 'https://www.yoshien.com',
        categoryUrl: 'https://www.yoshien.com/matcha/matcha-tee/',
        productSelector: '.cs-product-tile',
        nameSelector: '.cs-product-tile__name, .cs-product-tile__name-link',
        priceSelector: '.cs-product-tile__price',
        stockSelector: 'a[href*="matcha"]', // Links to matcha products indicate availability
        linkSelector: 'a[href*="/matcha-"]',
        stockKeywords: ['add to cart', 'in stock', 'verfügbar'],
        outOfStockKeywords: ['ausverkauft', 'out of stock', 'sold out']
      },
      'matcha-karu': {
        name: 'Matcha Kāru',
        baseUrl: 'https://matcha-karu.com',
        categoryUrl: 'https://matcha-karu.com/collections/matcha-tee',
        productSelector: '.product-item',
        nameSelector: '.product-item-meta__title, .product-item__info a',
        priceSelector: 'span.price, .price:not(.price--block)',
        stockSelector: '.price',
        linkSelector: '.product-item-meta__title, .product-item__info a',
        stockKeywords: ['add to cart', 'in den warenkorb', 'kaufen'],
        outOfStockKeywords: ['ausverkauft', 'nicht verfügbar', 'sold out']
      },
      'sho-cha': {
        name: 'Sho-Cha',
        baseUrl: 'https://www.sho-cha.com',
        categoryUrl: 'https://www.sho-cha.com/teeshop',
        productSelector: '.ProductList-item',
        nameSelector: '.ProductList-title, .ProductList-title a',
        priceSelector: '.product-price, .sqs-money-native, .ProductList-price',
        stockSelector: '.product-price',
        linkSelector: 'a, .ProductList-title a',
        stockKeywords: ['add to cart', 'kaufen', 'in den warenkorb'],
        outOfStockKeywords: ['ausverkauft', 'sold out', 'nicht verfügbar']
      },
      'sazentea': {
        name: 'Sazen Tea',
        baseUrl: 'https://www.sazentea.com',
        categoryUrl: 'https://www.sazentea.com/en/products/c21-matcha',
        productSelector: '.product',
        nameSelector: '.product-name',
        priceSelector: '.product-price',
        stockSelector: '.product-price', // Products with prices are available
        linkSelector: 'a[href*="/products/"]',
        stockKeywords: ['add to cart', 'in stock', 'available'],
        outOfStockKeywords: ['out of stock', 'sold out', 'unavailable']
      },
      'enjoyemeri': {
        name: 'Emeri',
        baseUrl: 'https://www.enjoyemeri.com',
        categoryUrl: 'https://www.enjoyemeri.com/collections/shop-all',
        productSelector: '.product-card',
        nameSelector: 'h3',
        priceSelector: '.price',
        stockSelector: '.price',
        linkSelector: 'a',
        stockKeywords: ['add to cart', 'buy now', 'purchase'],
        outOfStockKeywords: ['out of stock', 'sold out']
      },
      'poppatea': {
        name: 'Poppatea',
        baseUrl: 'https://poppatea.com',
        categoryUrl: 'https://poppatea.com/de-de/collections/all-teas?filter.p.m.custom.tea_type=Matcha',
        productSelector: '.card__container',
        nameSelector: 'h3',
        priceSelector: '.price__regular',
        stockSelector: 'h3', // Used only for main page, not variants
        linkSelector: 'a[href*="/products/"]',
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
        linkSelector: 'a[href*="/products/"]',
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

      // Extract products directly from the listing page
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
          // Extract product name
          let name = this.extractText(productElement, config.nameSelector);
          if (!name) {
            name = this.extractText(productElement, 'h1, h2, h3, h4, .title, .name');
          }
          
          // Clean up name
          name = name.replace(/\s+/g, ' ').trim();
          
          // Skip if no valid name found
          if (!name || name.length < 2) {
            continue;
          }

          // Extract price
          let price = this.extractText(productElement, config.priceSelector);
          if (!price) {
            price = this.extractText(productElement, '.price, .product-price, [class*="price"]');
          }

          // Clean price using site-specific logic
          price = this.cleanPriceBySite(price, siteKey);

          // Extract product URL
          let productUrl = this.extractLink(productElement, config.linkSelector);
          if (!productUrl) {
            productUrl = this.extractLink(productElement, 'a');
          }
          
          // Build full URL
          if (productUrl && !productUrl.startsWith('http')) {
            productUrl = config.baseUrl + (productUrl.startsWith('/') ? '' : '/') + productUrl;
          }

          // Determine stock status
          const isInStock = this.determineStockStatusFromListing(productElement, config, siteKey);

          // Generate product ID
          const productId = this.generateProductId(productUrl || config.categoryUrl, name, siteKey);

          const product = {
            id: productId,
            name: name,
            normalizedName: this.normalizeName(name),
            site: siteKey,
            siteName: config.name,
            price: price,
            originalPrice: price,
            priceValue: this.extractPriceValue(price),
            currency: 'EUR', // Default to EUR, will be normalized
            url: productUrl || config.categoryUrl,
            isInStock,
            category: this.detectCategory(name, siteKey),
            lastChecked: new Date(),
            lastUpdated: new Date(),
            firstSeen: new Date(),
            isDiscontinued: false,
            missedScans: 0,
            crawlSource: 'cloud-run'
          };

          // Only add products with valid names
          if (product.name && product.name.trim().length > 0) {
            products.push(product);

            // Save to Firestore and check for stock changes
            const wasUpdated = await this.saveProduct(product);
            if (wasUpdated) stockUpdates++;

            this.logger.info('Product extracted', {
              site: siteKey,
              name: product.name,
              price: product.price,
              inStock: product.isInStock,
              url: product.url
            });
          }

        } catch (error) {
          this.logger.warn('Failed to extract product from container', {
            site: siteKey,
            containerIndex: i,
            error: error.message
          });
        }
      }

      const duration = Date.now() - startTime;

      this.logger.info('Site crawl completed', {
        site: siteKey,
        productsFound: products.length,
        stockUpdates,
        duration: `${duration}ms`
      });

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
   * Extract text content using multiple selectors
   */
  extractText(element, selectors) {
    const selectorList = selectors.split(',').map(s => s.trim());
    
    for (const selector of selectorList) {
      const found = element.find(selector).first();
      if (found.length > 0) {
        let text = found.text().trim();
        if (text) return text;
      }
    }
    return '';
  }

  /**
   * Extract link href using multiple selectors
   */
  extractLink(element, selectors) {
    const selectorList = selectors.split(',').map(s => s.trim());
    
    for (const selector of selectorList) {
      const found = element.find(selector).first();
      if (found.length > 0) {
        const href = found.attr('href');
        if (href) return href;
      }
    }
    return '';
  }

  /**
   * Determine stock status from listing page element (not individual product page)
   */
  determineStockStatusFromListing(productElement, config, siteKey) {
    const elementText = productElement.text().toLowerCase();
    
    switch (siteKey) {
      case 'tokichi':
        // For Tokichi, check if "Out of stock" text is present
        return !elementText.includes('out of stock') && !elementText.includes('sold out');

      case 'ippodo':
        // For Ippodo, check for .out-of-stock class
        const outOfStockElement = productElement.find('.out-of-stock');
        return outOfStockElement.length === 0;

      case 'marukyu':
        // For Marukyu, check for stock classes and buttons
        if (productElement.find('.instock').length > 0) return true;
        if (productElement.find('.outofstock').length > 0) return false;
        // Check for add to cart button
        const addToCartBtn = productElement.find('.cart-form button:not([disabled]), .add-to-cart:not(.disabled)');
        return addToCartBtn.length > 0;

      case 'yoshien':
        // For Yoshi En, check for out-of-stock class and German text
        if (productElement.find('.cs-product-tile--out-of-stock').length > 0) return false;
        if (elementText.includes('ausverkauft') || elementText.includes('nicht verfügbar')) return false;
        return true;

      case 'matcha-karu':
        // For Matcha Kāru, check if price is present and no out-of-stock text
        const priceElement = productElement.find(config.priceSelector);
        if (priceElement.length === 0 || !priceElement.text().trim()) return false;
        return !elementText.includes('ausverkauft') && !elementText.includes('nicht verfügbar');

      case 'sho-cha':
        // For Sho-Cha, check for sold-out CSS class and German text
        if (productElement.find('.sold-out').length > 0) return false;
        if (elementText.includes('ausverkauft') || elementText.includes('nicht verfügbar')) return false;
        const priceEl = productElement.find(config.priceSelector);
        return priceEl.length > 0 && priceEl.text().trim() !== '';

      case 'sazentea':
        // For Sazen Tea, check for price presence and stock indicators
        if (elementText.includes('out of stock') || elementText.includes('sold out')) return false;
        const priceExists = productElement.find(config.priceSelector).length > 0;
        return priceExists;

      case 'enjoyemeri':
        // For Enjoyemeri (Shopify), check for price and no out of stock text
        const priceAvailable = productElement.find(config.priceSelector).length > 0;
        return priceAvailable && !elementText.includes('out of stock') && !elementText.includes('sold out');

      case 'poppatea':
        // For Poppatea, check for German out-of-stock indicators
        if (elementText.includes('ausverkauft') || elementText.includes('nicht verfügbar') || 
            elementText.includes('sold out') || elementText.includes('out of stock')) return false;
        return true;

      case 'horiishichimeien':
        // For Horiishichimeien, check for Japanese and English out-of-stock indicators
        if (elementText.includes('売り切れ') || elementText.includes('out of stock') || 
            elementText.includes('sold out') || elementText.includes('unavailable')) return false;
        // Check for add to cart button or similar indicators
        const addToCartExists = productElement.find(config.stockSelector).length > 0;
        return addToCartExists;

      default:
        // Fallback: check for stock keywords vs out-of-stock keywords
        const hasStockKeywords = config.stockKeywords.some(keyword => 
          elementText.includes(keyword.toLowerCase())
        );
        const hasOutOfStockKeywords = config.outOfStockKeywords.some(keyword => 
          elementText.includes(keyword.toLowerCase())
        );
        
        if (hasOutOfStockKeywords) return false;
        if (hasStockKeywords) return true;
        
        // Final fallback: check if price is present
        return productElement.find(config.priceSelector).length > 0;
    }
  }

  /**
   * Normalize product name for better matching
   */
  normalizeName(name) {
    return name
      .toLowerCase()
      .replace(/[^\w\s]/g, ' ') // Replace non-alphanumeric with spaces
      .replace(/\s+/g, ' ') // Replace multiple spaces with single space
      .trim();
  }

  /**
   * Detect product category based on name and site
   */
  detectCategory(name, site) {
    const lower = name.toLowerCase();

    // Check for accessories first (most specific)
    if (lower.includes('whisk') || lower.includes('chasen') || lower.includes('bowl') || 
        lower.includes('chawan') || lower.includes('scoop') || lower.includes('chashaku')) {
      return 'Accessories';
    }

    // Check for tea sets (also specific)
    if (lower.includes('set') || lower.includes('kit')) {
      return 'Tea Sets';
    }

    // Other tea types (before matcha to catch specific teas)
    if (lower.includes('genmaicha')) return 'Genmaicha';
    if (lower.includes('hojicha')) return 'Hojicha';
    if (lower.includes('black tea') || lower.includes('earl grey')) return 'Black Tea';

    // Matcha - check last since it's most common
    if (lower.includes('matcha')) {
      // Sub-categorize matcha
      if (lower.includes('ceremonial') || lower.includes('ceremony')) return 'Ceremonial Matcha';
      if (lower.includes('premium') || lower.includes('grade a')) return 'Premium Matcha';
      if (lower.includes('cooking') || lower.includes('culinary')) return 'Culinary Matcha';
      return 'Matcha';
    }

    // Default category
    const lowerSite = site.toLowerCase();
    if (lowerSite.includes('matcha') || lowerSite.includes('tea')) {
      return 'Matcha'; // Default for tea sites
    }

    return 'Matcha'; // Default fallback
  }

  /**
   * Extract numeric price value from price string
   */
  extractPriceValue(priceString) {
    if (!priceString) return null;

    // Remove currency symbols and common text
    const cleaned = priceString.replace(/[€$¥£]/g, '').replace(/[^\d.,]/g, '');
    
    // Extract the first number with decimal places
    const priceMatch = cleaned.match(/(\d+)[.,](\d+)/);
    if (priceMatch) {
      const wholePart = parseInt(priceMatch[1]);
      const decimalPart = parseInt(priceMatch[2]) / 100;
      return wholePart + decimalPart;
    }

    // Try extracting integer prices
    const intMatch = cleaned.match(/(\d+)/);
    if (intMatch) {
      return parseInt(intMatch[1]);
    }

    return null;
  }

  /**
   * Clean price string based on site-specific logic (matches Flutter CurrencyPriceService)
   */
  cleanPriceBySite(rawPrice, siteKey) {
    if (!rawPrice) return '';

    let cleaned = rawPrice.trim();

    switch (siteKey) {
      case 'tokichi':
        // Fix duplicate price issue: €28,00€28,00 -> €28,00
        const duplicateMatch = cleaned.match(/(€\d+[.,]\d+)€\d+[.,]\d+/);
        if (duplicateMatch) {
          cleaned = duplicateMatch[1];
        }

        // Extract Euro price
        const euroMatch = cleaned.match(/€(\d+[.,]\d+)/);
        if (euroMatch) {
          const priceText = euroMatch[1].replace(',', '.');
          return `€${priceText}`;
        }
        break;

      case 'marukyu':
        // Handle multi-currency format: "4209.61€8.26£7.15¥68.39"
        const eurMatch = cleaned.match(/€(\d+[.,]\d+)/);
        if (eurMatch) {
          const priceText = eurMatch[1].replace(',', '.');
          return `€${priceText}`;
        }

        // Handle tilde-separated format: "100~14.21~€12.21~"
        if (cleaned.includes('~')) {
          const euroTildeMatch = cleaned.match(/€([0-9.,]+)~/);
          if (euroTildeMatch) {
            return `€${euroTildeMatch[1]}`;
          }
        }

        // Convert other currencies to Euro (approximate rates)
        const usdMatch = cleaned.match(/[\$](\d+[.,]\d+)/);
        if (usdMatch) {
          const usdValue = parseFloat(usdMatch[1].replace(',', '.'));
          const euroValue = (usdValue * 0.92).toFixed(2); // 1 USD = 0.92 EUR
          return `€${euroValue}`;
        }

        const gbpMatch = cleaned.match(/£(\d+[.,]\d+)/);
        if (gbpMatch) {
          const gbpValue = parseFloat(gbpMatch[1].replace(',', '.'));
          const euroValue = (gbpValue * 1.16).toFixed(2); // 1 GBP = 1.16 EUR
          return `€${euroValue}`;
        }

        const jpyMatch = cleaned.match(/¥(\d+[.,]\d+)/);
        if (jpyMatch) {
          const jpyValue = parseFloat(jpyMatch[1].replace(',', ''));
          const euroValue = (jpyValue * 0.0067).toFixed(2); // 1 JPY = 0.0067 EUR
          return `€${euroValue}`;
        }
        break;

      case 'ippodo':
        // Extract Yen price and convert to Euro
        const jpyMatchIppodo = cleaned.match(/¥(\d+[.,]\d+)/);
        if (jpyMatchIppodo) {
          const jpyValue = parseFloat(jpyMatchIppodo[1].replace(',', ''));
          const euroValue = (jpyValue * 0.0067).toFixed(2);
          return `€${euroValue}`;
        }

        // Handle format without currency symbol (assume JPY)
        const numMatch = cleaned.match(/(\d+[.,]\d+)/);
        if (numMatch) {
          const jpyValue = parseFloat(numMatch[1].replace(',', ''));
          const euroValue = (jpyValue * 0.0067).toFixed(2);
          return `€${euroValue}`;
        }
        break;

      case 'sho-cha':
        // Handle German Euro formatting: "24,00 €"
        cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
        const euroPriceMatch = cleaned.match(/(\d+(?:,\d{2})?)\s*€/);
        if (euroPriceMatch) {
          return euroPriceMatch[1] + ' €';
        }
        
        // Try USD format and convert
        const usdPriceMatch = cleaned.match(/\$(\d+(?:\.\d{2})?)/);
        if (usdPriceMatch) {
          const usdValue = parseFloat(usdPriceMatch[1]);
          const euroValue = (usdValue * 0.92).toFixed(2);
          return `€${euroValue}`;
        }
        break;

      case 'matcha-karu':
        // Handle German price formatting: "AngebotspreisAb 19,00 €"
        cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
        cleaned = cleaned.replace(/Angebotspreis/g, '');
        cleaned = cleaned.replace(/Ab /g, '');
        cleaned = cleaned.replace(/ab /g, '');
        
        const matchaKaruMatch = cleaned.match(/(\d+,\d{2}\s*€)/);
        if (matchaKaruMatch) {
          return matchaKaruMatch[1];
        }
        break;

      case 'poppatea':
        // Handle German price format (€XX,XX or XX,XX €)
        cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
        const poppateaMatch = cleaned.match(/€?(\d+,\d{2})\s*€?/);
        if (poppateaMatch) {
          return `€${poppateaMatch[1]}`;
        }
        break;

      case 'yoshien':
        // Clean up the text and extract price
        cleaned = cleaned.replace('Ab ', '').trim();
        const yoshienMatch = cleaned.match(/(\d+[.,]\d+)\s*€/);
        if (yoshienMatch) {
          return yoshienMatch[1] + ' €';
        }
        break;

      case 'sazentea':
        // Extract USD price and convert
        cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
        const sazenMatch = cleaned.match(/\$(\d+\.\d+)/);
        if (sazenMatch) {
          const usdValue = parseFloat(sazenMatch[1]);
          const euroValue = (usdValue * 0.92).toFixed(2);
          return `€${euroValue}`;
        }
        break;

      case 'enjoyemeri':
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

        // Check for price change or track price regularly
        const shouldTrackPrice = product.priceValue != null && (
          existingData.priceValue !== product.priceValue || 
          this.shouldAddPriceHistoryEntry(existingData)
        );

        if (shouldTrackPrice) {
          if (existingData.priceValue !== product.priceValue) {
            wasUpdated = true;
            
            // Log price change
            this.logger.info('Price changed', {
              productId: product.id,
              name: product.name,
              site: product.site,
              previousPrice: existingData.priceValue,
              newPrice: product.priceValue
            });
          }

          // Add to price history (for both price changes and regular tracking)
          await this.db.collection('price_history').add({
            productId: product.id,
            productName: product.name,
            site: product.site,
            price: product.priceValue,
            currency: product.currency,
            isInStock: product.isInStock,
            date: new Date(),
            crawlSource: 'cloud-run'
          });
        }

        // Update existing product
        const updateData = {
          ...product,
          lastChecked: new Date(),
          lastUpdated: wasUpdated ? new Date() : existingData.lastUpdated
        };

        // Update lastPriceHistoryUpdate if we added a price history entry
        if (shouldTrackPrice) {
          updateData.lastPriceHistoryUpdate = new Date();
        }

        await productRef.update(updateData);
      } else {
        // New product
        const newProductData = {
          ...product,
          lastPriceHistoryUpdate: product.priceValue != null ? new Date() : null
        };

        await productRef.set(newProductData);
        wasUpdated = true;
        
        this.logger.info('New product added', {
          productId: product.id,
          name: product.name,
          site: product.site
        });

        // Add initial stock history entry for new product
        await this.db.collection('stock_history').add({
          productId: product.id,
          productName: product.name,
          site: product.site,
          isInStock: product.isInStock,
          previousStatus: null,
          timestamp: new Date(),
          crawlSource: 'cloud-run'
        });

        // Add initial price history entry for new product (if price is available)
        if (product.priceValue != null) {
          await this.db.collection('price_history').add({
            productId: product.id,
            productName: product.name,
            site: product.site,
            price: product.priceValue,
            currency: product.currency,
            isInStock: product.isInStock,
            date: new Date(),
            crawlSource: 'cloud-run'
          });
        }
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
   * Determine if we should add a price history entry for regular tracking
   * (even when price hasn't changed)
   */
  shouldAddPriceHistoryEntry(existingData) {
    if (!existingData.lastPriceHistoryUpdate) {
      return true; // First time tracking
    }

    const lastUpdate = new Date(existingData.lastPriceHistoryUpdate);
    const now = new Date();
    const hoursSinceLastUpdate = (now - lastUpdate) / (1000 * 60 * 60);

    // Add price history entry every 24 hours for regular tracking
    return hoursSinceLastUpdate >= 24;
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
