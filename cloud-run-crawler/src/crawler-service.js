const axios = require('axios');
const cheerio = require('cheerio');
const { v4: uuidv4 } = require('uuid');
const sharp = require('sharp');
const { getStorage } = require('firebase-admin/storage');

/**
 * Cloud-based crawler service for matcha websites
 * Optimized for parallel processing and delta crawling
 */
class CrawlerService {
  constructor(firestore, logger) {
    this.db = firestore;
    this.logger = logger;
    this.userAgent = 'ZenRadar Bot 1.0 (+https://zenradar.app)';
    this.storage = getStorage();
    
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
        stockSelector: '.out-of-stock', // Products are out of stock if this element exists
        linkSelector: 'a[href*="/products/"]',
        imageSelector: '.m-product-card__image img, .product-card__media img',
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
        imageSelector: '.cs-product-tile__image img, .product-image img',
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
        imageSelector: '.product-item__image img, .product-item__media img',
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
        imageSelector: '.ProductList-image img, .product-image img',
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
        imageSelector: 'img[src*="/content/products/"], .product-image-img, img[alt*="Matcha"]:not([alt*="Best"]):not([alt*="Selling"]):not([alt*="Specialty"]):not([alt*="Extra"])',
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
        imageSelector: '.product-card__image img, .product-image img',
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
        imageSelector: '.card__media img, .media img, img[src*="product"]',
        stockKeywords: ['add to cart', 'in den warenkorb', 'kaufen'],
        outOfStockKeywords: ['ausverkauft', 'nicht verfügbar', 'sold out', 'notify me']
      },
      'horiishichimeien': {
        name: 'Horiishichimeien',
        baseUrl: 'https://horiishichimeien.com',
        categoryUrl: 'https://horiishichimeien.com/en/collections/all?selected=%E6%8A%B9%E8%8C%B6',
        productSelector: '.grid__item',
        nameSelector: 'a[href*="/products/"]',
        priceSelector: '.price, .price__regular, .money, .price-item',
        stockSelector: '.product-form__buttons, .product-form, form[action="/cart/add"], button[name="add"]',
        linkSelector: 'a[href*="/products/"]',
        imageSelector: '.card__media img, .grid-product__image img, .product__media img, img[alt*="Matcha"]',
        stockKeywords: ['add to cart', 'buy now', 'purchase', 'add to bag', 'カートに入れる'],
        outOfStockKeywords: ['sold out', 'unavailable', '売り切れ', 'out of stock'],
        currencyConversion: {
          from: 'JPY',
          to: 'EUR',
          rate: 0.0062 // 1 JPY = 0.0062 EUR (approximate, should be updated regularly)
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

          // Extract product URL
          let productUrl = this.extractLink(productElement, config.linkSelector);
          if (!productUrl) {
            productUrl = this.extractLink(productElement, 'a');
          }
          
          // Build full URL
          if (productUrl && !productUrl.startsWith('http')) {
            productUrl = config.baseUrl + (productUrl.startsWith('/') ? '' : '/') + productUrl;
          }

          // For Poppatea, extract variants from individual product pages
          if (siteKey === 'poppatea' && productUrl) {
            try {
              const variants = await this.extractPoppateaVariants(productUrl, name, config);
              for (const variant of variants) {
                products.push(variant);
                const wasUpdated = await this.saveProduct(variant);
                if (wasUpdated) stockUpdates++;
              }
              continue; // Skip the regular product processing for Poppatea
            } catch (error) {
              this.logger.warn('Failed to extract Poppatea variants', {
                site: siteKey,
                productUrl,
                error: error.message
              });
              // Fall back to regular processing
            }
          }

          // Extract price
          let price = this.extractText(productElement, config.priceSelector);
          if (!price) {
            price = this.extractText(productElement, '.price, .product-price, [class*="price"]');
          }

          // Clean price using site-specific logic
          price = this.cleanPriceBySite(price, siteKey);
          
          // Convert price if needed (e.g., JPY to EUR for Horiishichimeien)
          const convertedPrice = this.convertPrice(price, siteKey);

          // Determine stock status
          const isInStock = this.determineStockStatusFromListing(productElement, config, siteKey);

          // Generate product ID
          const productId = this.generateProductId(productUrl || config.categoryUrl, name, siteKey);

          // Extract and process image
          let imageUrl = null;
          try {
            const rawImageUrl = this.extractImageUrl(productElement, config, siteKey);
            if (rawImageUrl) {
              imageUrl = await this.downloadAndStoreImage(rawImageUrl, productId, siteKey);
            }
          } catch (error) {
            this.logger.warn('Failed to process product image', {
              site: siteKey,
              productId,
              error: error.message
            });
          }

          const product = {
            id: productId,
            name: name,
            normalizedName: this.normalizeName(name),
            site: siteKey,
            siteName: config.name,
            price: convertedPrice || price,
            originalPrice: price, // Keep original price
            priceValue: this.extractPriceValue(convertedPrice || price),
            currency: this.getCurrencyForSite(siteKey),
            url: productUrl || config.categoryUrl,
            imageUrl: imageUrl,
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
   * Get currency for site
   */
  getCurrencyForSite(siteKey) {
    const config = this.siteConfigs[siteKey];
    if (config && config.currencyConversion) {
      return config.currencyConversion.to;
    }
    return 'EUR'; // Default currency
  }

  /**
   * Convert price if currency conversion is configured
   */
  convertPrice(price, siteKey) {
    const config = this.siteConfigs[siteKey];
    if (!config || !config.currencyConversion || !price) {
      return price;
    }

    // Extract numeric value from price
    const numericValue = this.extractPriceValue(price);
    if (numericValue === null) {
      return price;
    }

    // Convert currency
    const convertedValue = numericValue * config.currencyConversion.rate;
    
    // Format as target currency
    return `€${convertedValue.toFixed(2)}`;
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
        // First check for explicit sold-out badges or text
        if (productElement.find('.price__badge--sold-out, .sold-out-badge, .out-of-stock, .badge--sold-out').length > 0) {
          return false;
        }
        
        // Check for "SOLD OUT" text in the element
        if (elementText.includes('sold out') || elementText.includes('unavailable') || 
            elementText.includes('売り切れ') || elementText.includes('out of stock')) {
          return false;
        }
        
        // Check for price presence - Horiishichimeien shows price for available items
        const hpriceElement = productElement.find(config.priceSelector);
        const hpriceText = hpriceElement.text().trim();
        
        // If no price element or price is empty/invalid, consider out of stock
        if (!hpriceElement.length || !hpriceText || hpriceText.length < 2) {
          return false;
        }
        
        // If price contains "¥" and a number, it's likely in stock
        if (hpriceText.includes('¥') && /\d/.test(hpriceText)) {
          return true;
        }
        
        // Check if there's a visible link to the product (products without links might be unavailable)
        const hasValidLink = productElement.find('a[href*="/products/"]').length > 0;
        
        // Product is in stock if it has a valid price and a valid link
        return hasValidLink && hpriceText.length > 0;

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
        const poppateaMatch = cleaned.match(/€?\s*(\d+[,.]\d{2})\s*€?/);
        if (poppateaMatch) {
          const price = poppateaMatch[1].replace(',', '.');
          return `€${price}`;
        }
        // Also try to match prices without decimals
        const simpleMatch = cleaned.match(/€?\s*(\d+)\s*€?/);
        if (simpleMatch) {
          return `€${simpleMatch[1]}.00`;
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
        // For Horiishichimeien, handle Japanese Yen prices and avoid duplication
        // Remove extra whitespace and normalize
        cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
        // Extract only the first occurrence of Yen price to avoid duplication
        const yenMatch = cleaned.match(/¥(\d+[.,]?\d*)/);
        if (yenMatch) {
          return yenMatch[0]; // Return the full match (¥XXX)
        }
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
   * Extract variants from Poppatea product page
   */
  async extractPoppateaVariants(productUrl, baseName, config) {
    try {
      const response = await axios.get(productUrl, this.requestConfig);
      const $ = cheerio.load(response.data);
      const variants = [];

      // Extract main product image
      let mainImageUrl = null;
      try {
        const imageSelectors = [
          '.product__media img',
          '.product-single__photos img',
          '.product__photo img',
          'img[src*="product"]'
        ];
        
        for (const selector of imageSelectors) {
          const img = $(selector).first();
          if (img.length) {
            let imgSrc = img.attr('src') || img.attr('data-src');
            if (imgSrc) {
              if (imgSrc.startsWith('//')) {
                imgSrc = 'https:' + imgSrc;
              } else if (imgSrc.startsWith('/')) {
                imgSrc = config.baseUrl + imgSrc;
              }
              mainImageUrl = imgSrc.split('?')[0]; // Remove query params
              break;
            }
          }
        }
      } catch (imageError) {
        this.logger.warn('Failed to extract product image', { productUrl, error: imageError.message });
      }

      // Process main image once for all variants
      let processedMainImageUrl = null;
      if (mainImageUrl) {
        try {
          const tempProductId = this.generateProductId(productUrl, baseName, 'poppatea');
          processedMainImageUrl = await this.downloadAndStoreImage(mainImageUrl, tempProductId, 'poppatea');
        } catch (imageError) {
          this.logger.warn('Failed to process main product image', { productUrl, error: imageError.message });
        }
      }

      // Method 1: Look for Shopify product JSON (most reliable)
      const scriptTags = $('script[type="application/json"], script:contains("variants"), script:contains("product")');
      let foundInJson = false;
      
      scriptTags.each((_, script) => {
        if (foundInJson) return;
        
        try {
          let jsonData;
          const scriptContent = $(script).html();
          
          // Skip if this looks like window object or other non-JSON
          if (scriptContent.trim().startsWith('window.') || 
              scriptContent.includes('window.Shopify') ||
              scriptContent.includes('function(')) {
            return;
          }
          
          // Try to parse as JSON
          try {
            jsonData = JSON.parse(scriptContent);
          } catch (e) {
            // If direct parsing fails, look for JSON within the script
            const jsonMatches = [
              scriptContent.match(/product["\s]*:[^{]*({[^}]+variants[^}]+})/),
              scriptContent.match(/variants["\s]*:\s*(\[[^\]]+\])/),
              scriptContent.match(/"product":\s*({[^}]+variants[^}]+})/),
            ];
            
            for (const match of jsonMatches) {
              if (match) {
                try {
                  jsonData = JSON.parse(match[1]);
                  break;
                } catch (e2) {
                  // Continue trying
                }
              }
            }
          }
          
          if (jsonData && jsonData.variants) {
            this.logger.info('Found Shopify product JSON with variants', { 
              productUrl, 
              variantCount: jsonData.variants.length 
            });
            
            for (const variant of jsonData.variants) {
              const sizeName = variant.title || variant.option1 || variant.option2 || '';
              const variantName = sizeName ? `${baseName} - ${sizeName}` : baseName;
              
              // Calculate product ID for this variant
              const variantId = this.generateProductId(productUrl, variantName, 'poppatea');
              
              const variantProduct = {
                id: variantId,
                name: variantName.trim(),
                normalizedName: this.normalizeName(variantName),
                site: 'poppatea',
                siteName: config.name,
                price: variant.price ? `€${(variant.price / 100).toFixed(2)}` : '',
                originalPrice: variant.price ? `€${(variant.price / 100).toFixed(2)}` : '',
                priceValue: variant.price ? variant.price / 100 : 0,
                currency: 'EUR',
                url: productUrl,
                imageUrl: processedMainImageUrl,
                isInStock: variant.available || false,
                category: this.detectCategory(baseName, 'poppatea'),
                lastChecked: new Date(),
                lastUpdated: new Date(),
                firstSeen: new Date(),
                isDiscontinued: false,
                missedScans: 0,
                crawlSource: 'cloud-run',
                variantId: variant.id
              };
              variants.push(variantProduct);
            }
            foundInJson = true;
          }
        } catch (e) {
          // Continue if JSON parsing fails
        }
      });

      // Method 2: Look for variant selectors (HTML forms)
      if (!foundInJson) {
        const variantSelectors = $('select[name="id"], .product-form__option select, input[name="id"]');
        
        if (variantSelectors.length > 0) {
          this.logger.info('Found variant selectors', { productUrl, selectorCount: variantSelectors.length });
          
          variantSelectors.each((_, element) => {
            const $element = $(element);
            
            if ($element.is('input')) {
              // Handle radio buttons or other input elements
              const value = $element.attr('value');
              const label = $element.next('label').text() || 
                           $element.parent().text() || 
                           $element.siblings('label').text() ||
                           $element.attr('data-variant-title') || '';
              
              if (value && label) {
                this.logger.info('Found input variant', { value, label: label.trim() });
                const variant = this.parseVariantText(label.trim(), baseName);
                if (variant) {
                  const variantId = this.generateProductId(productUrl, variant.name, 'poppatea');
                  
                  variant.id = variantId;
                  variant.site = 'poppatea';
                  variant.siteName = config.name;
                  variant.url = productUrl;
                  variant.imageUrl = processedMainImageUrl;
                  variant.category = this.detectCategory(baseName, 'poppatea');
                  variant.lastChecked = new Date();
                  variant.lastUpdated = new Date();
                  variant.firstSeen = new Date();
                  variant.isDiscontinued = false;
                  variant.missedScans = 0;
                  variant.crawlSource = 'cloud-run';
                  variant.variantId = value;
                  
                  // Check stock status for this variant
                  variant.isInStock = this.checkVariantStock($, value, label);
                  
                  variants.push(variant);
                }
              }
            } else {
              // Handle select dropdowns
              $element.find('option').each((_, option) => {
                const $option = $(option);
                const value = $option.attr('value');
                const text = $option.text().trim();
                
                if (value && text && !text.toLowerCase().includes('select') && !text.includes('---')) {
                  // Parse variant info (typically includes size and price)
                  const variant = this.parseVariantText(text, baseName);
                  if (variant) {
                    const variantId = this.generateProductId(productUrl, variant.name, 'poppatea');
                    
                    variant.id = variantId;
                    variant.site = 'poppatea';
                    variant.siteName = config.name;
                    variant.url = productUrl;
                    variant.imageUrl = processedMainImageUrl;
                    variant.category = this.detectCategory(baseName, 'poppatea');
                    variant.lastChecked = new Date();
                    variant.lastUpdated = new Date();
                    variant.firstSeen = new Date();
                    variant.isDiscontinued = false;
                    variant.missedScans = 0;
                    variant.crawlSource = 'cloud-run';
                    variant.variantId = value;
                    
                    // Check stock status for this variant
                    variant.isInStock = this.checkVariantStock($, value, text);
                    
                    variants.push(variant);
                  }
                }
              });
            }
          });
        }
      }

      // Method 3: Look for size/variant buttons or labels
      if (variants.length === 0) {
        const sizeButtons = $('.product-form__buttons input[type="radio"], .size-variant, .variant-option');
        
        if (sizeButtons.length > 0) {
          this.logger.info('Found size variant buttons', { productUrl, buttonCount: sizeButtons.length });
          
          sizeButtons.each((_, element) => {
            const $element = $(element);
            const value = $element.attr('value') || $element.attr('data-value');
            const label = $element.next('label').text() || $element.attr('data-title') || '';
            
            if (label && value) {
              const variantName = `${baseName} - ${label}`;
              const variantId = this.generateProductId(productUrl, variantName, 'poppatea');
              
              // Try to extract price from nearby elements or use main price
              let price = '';
              const priceElement = $element.closest('.variant-option').find('.price, .variant-price');
              if (priceElement.length > 0) {
                price = this.cleanPriceBySite(priceElement.text(), 'poppatea');
              } else {
                price = this.cleanPriceBySite($('.price__regular, .price').first().text(), 'poppatea');
              }
              
              variants.push({
                id: variantId,
                name: variantName,
                normalizedName: this.normalizeName(variantName),
                site: 'poppatea',
                siteName: config.name,
                price: price,
                originalPrice: price,
                priceValue: this.extractPriceValue(price),
                currency: 'EUR',
                url: productUrl,
                imageUrl: processedMainImageUrl,
                isInStock: !$element.is(':disabled') && !$element.hasClass('disabled'),
                category: this.detectCategory(baseName, 'poppatea'),
                lastChecked: new Date(),
                lastUpdated: new Date(),
                firstSeen: new Date(),
                isDiscontinued: false,
                missedScans: 0,
                crawlSource: 'cloud-run',
                variantId: value
              });
            }
          });
        }
      }

      // If still no variants found, create a single product
      if (variants.length === 0) {
        const price = this.extractText($('.price__regular, .price'), '');
        const cleanedPrice = this.cleanPriceBySite(price, 'poppatea');
        const productId = this.generateProductId(productUrl, baseName, 'poppatea');
        
        variants.push({
          id: productId,
          name: baseName,
          normalizedName: this.normalizeName(baseName),
          site: 'poppatea',
          siteName: config.name,
          price: cleanedPrice,
          originalPrice: cleanedPrice,
          priceValue: this.extractPriceValue(cleanedPrice),
          currency: 'EUR',
          url: productUrl,
          imageUrl: processedMainImageUrl,
          isInStock: !($('.sold-out, .unavailable').length > 0 || 
                      $('body').text().toLowerCase().includes('ausverkauft')),
          category: this.detectCategory(baseName, 'poppatea'),
          lastChecked: new Date(),
          lastUpdated: new Date(),
          firstSeen: new Date(),
          isDiscontinued: false,
          missedScans: 0,
          crawlSource: 'cloud-run'
        });
      }

      this.logger.info('Extracted Poppatea variants', {
        productUrl,
        baseName,
        variantCount: variants.length,
        method: foundInJson ? 'JSON' : 'HTML'
      });

      return variants;
    } catch (error) {
      this.logger.error('Failed to extract Poppatea variants', {
        productUrl,
        error: error.message,
        stack: error.stack
      });
      return [];
    }
  }

  /**
   * Parse variant text to extract size and price information
   */
  parseVariantText(text, baseName) {
    // Common patterns for Poppatea variants: "50g - €12.50", "100g / €25.00"
    const patterns = [
      /(\d+g)\s*[-\/]\s*€(\d+[,.]?\d*)/,  // "50g - €12.50"
      /(\d+g)\s*\(\s*€(\d+[,.]?\d*)\)/,   // "50g (€12.50)"
      /(\d+g)\s*€(\d+[,.]?\d*)/,          // "50g €12.50"
      /(\d+\s*ml)\s*[-\/]\s*€(\d+[,.]?\d*)/, // For liquid products
    ];

    for (const pattern of patterns) {
      const match = text.match(pattern);
      if (match) {
        const size = match[1];
        let price = match[2].replace(',', '.');
        
        return {
          name: `${baseName} (${size})`,
          normalizedName: this.normalizeName(`${baseName} ${size}`),
          price: `€${price}`,
          originalPrice: `€${price}`,
          priceValue: parseFloat(price),
          currency: 'EUR'
        };
      }
    }

    // If no pattern matches, try to extract just the size/variant info
    const sizeMatch = text.match(/(\d+\s*(?:g|ml|kg))/i);
    if (sizeMatch) {
      return {
        name: `${baseName} (${sizeMatch[1]})`,
        normalizedName: this.normalizeName(`${baseName} ${sizeMatch[1]}`),
        price: '',
        originalPrice: '',
        priceValue: 0,
        currency: 'EUR'
      };
    }

    // Fallback: use the text as variant name if it seems meaningful
    if (text.length > 2 && text.length < 50) {
      return {
        name: `${baseName} - ${text}`,
        normalizedName: this.normalizeName(`${baseName} ${text}`),
        price: '',
        originalPrice: '',
        priceValue: 0,
        currency: 'EUR'
      };
    }

    return null;
  }

  /**
   * Check stock status for a specific variant
   */
  checkVariantStock($, variantId, variantText) {
    // Check if the variant option is disabled (usually indicates out of stock)
    const option = $(`option[value="${variantId}"]`);
    if (option.attr('disabled')) {
      return false;
    }

    // Check for out of stock text in the variant text
    const lowerText = variantText.toLowerCase();
    if (lowerText.includes('ausverkauft') || lowerText.includes('sold out') || 
        lowerText.includes('nicht verfügbar') || lowerText.includes('unavailable')) {
      return false;
    }

    // Check for general out of stock indicators on the page
    const pageText = $('body').text().toLowerCase();
    if (pageText.includes('ausverkauft') || pageText.includes('sold out')) {
      // If general out of stock, but this specific variant doesn't mention it, it might be available
      return !lowerText.includes('not available');
    }

    return true; // Assume in stock if no negative indicators
  }

  /**
   * Generate consistent product ID
   */
  generateProductId(url, name, siteKey) {
    let urlPart = url.split('/').pop() || '';
    const namePart = name.toLowerCase().replace(/[^a-z0-9]/g, '').substring(0, 20);
    const sitePrefix = siteKey ? `${siteKey}_` : '';
    
    // For Poppatea, remove URL parameters and dynamic variant ID parts to ensure stable IDs
    if (siteKey === 'poppatea') {
      // First, remove URL parameters (everything after ?)
      urlPart = urlPart.split('?')[0];
      
      // Convert to lowercase and remove non-alphanumeric characters
      urlPart = urlPart.toLowerCase().replace(/[^a-z0-9]/g, '');
      
      return `${sitePrefix}${urlPart}_${namePart}`.replace(/[^a-z0-9_]/g, '');
    }
    
    // For other sites, clean the URL part normally
    urlPart = urlPart.split('?')[0]; // Remove URL parameters for all sites
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
   * Download and compress image, then upload to Firebase Storage
   */
  async downloadAndStoreImage(imageUrl, productId, siteKey) {
    try {
      if (!imageUrl || imageUrl.includes('data:') || imageUrl.includes('placeholder')) {
        return null;
      }

      // Make URL absolute if relative
      let absoluteUrl = imageUrl;
      if (imageUrl.startsWith('//')) {
        absoluteUrl = 'https:' + imageUrl;
      } else if (imageUrl.startsWith('/')) {
        const config = this.siteConfigs[siteKey];
        absoluteUrl = config.baseUrl + imageUrl;
      }

      this.logger.info('Downloading image', { 
        productId, 
        siteKey, 
        imageUrl: absoluteUrl 
      });

      // Download image
      const response = await axios({
        method: 'GET',
        url: absoluteUrl,
        responseType: 'arraybuffer',
        timeout: 15000,
        headers: {
          'User-Agent': this.userAgent,
          'Accept': 'image/*',
        }
      });

      // Compress image using Sharp
      const compressedImageBuffer = await sharp(response.data)
        .resize(400, 400, { 
          fit: 'inside', 
          withoutEnlargement: true 
        })
        .jpeg({ 
          quality: 85,
          progressive: true 
        })
        .toBuffer();

      // Upload to Firebase Storage
      const fileName = `product-images/${siteKey}/${productId}.jpg`;
      const file = this.storage.bucket().file(fileName);
      
      await file.save(compressedImageBuffer, {
        metadata: {
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=86400', // 1 day cache
        }
      });

      // Make file publicly accessible
      await file.makePublic();

      // Return public URL
      const publicUrl = `https://storage.googleapis.com/${this.storage.bucket().name}/${fileName}`;
      
      this.logger.info('Image uploaded successfully', { 
        productId, 
        siteKey,
        publicUrl,
        originalSize: response.data.length,
        compressedSize: compressedImageBuffer.length
      });

      return publicUrl;

    } catch (error) {
      this.logger.error('Failed to download and store image', {
        productId,
        siteKey,
        imageUrl,
        error: error.message
      });
      return null;
    }
  }

  /**
   * Extract image URL from product element
   */
  extractImageUrl(productElement, config, siteKey) {
    if (!config.imageSelector) return null;

    const selectors = config.imageSelector.split(',').map(s => s.trim());
    
    for (const selector of selectors) {
      const img = productElement.find(selector).first();
      if (img.length) {
        let imageUrl = img.attr('src') || img.attr('data-src') || img.attr('data-original');
        
        // Handle lazy loading attributes
        if (!imageUrl) {
          imageUrl = img.attr('data-lazy') || img.attr('data-srcset');
          if (imageUrl && imageUrl.includes(',')) {
            // Extract first URL from srcset
            imageUrl = imageUrl.split(',')[0].trim().split(' ')[0];
          }
        }

        if (imageUrl) {
          // Remove query parameters for cleaner URLs
          imageUrl = imageUrl.split('?')[0];
          return imageUrl;
        }
      }
    }

    return null;
  }
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
