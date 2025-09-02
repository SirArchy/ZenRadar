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
      'matcha-karu': {
        name: 'Matcha Kāru',
        baseUrl: 'https://matcha-karu.com',
        categoryUrl: 'https://matcha-karu.com/collections/matcha-tee',
        productSelector: '.product-item',
        nameSelector: 'a[href*="/products/"] img[alt], a[href*="/products/"]:nth-of-type(2)', // Use image alt text or second link
        priceSelector: '.price, .price__current, .price-item',
        stockSelector: '.product-form, .add-to-cart:not(.disabled)', 
        linkSelector: 'a[href*="/products/"]:first',
        imageSelector: '.product-item__aspect-ratio img, .product-item__image img, img[src*="products/"]',
        stockKeywords: ['add to cart', 'in den warenkorb', 'kaufen', 'angebotspreis'],
        outOfStockKeywords: ['ausverkauft', 'nicht verfügbar', 'sold out']
      },
      'sho-cha': {
        name: 'Sho-Cha',
        baseUrl: 'https://www.sho-cha.com',
        categoryUrl: 'https://www.sho-cha.com/teeshop',
        productSelector: 'h1', // Use H1 elements as product containers
        nameSelector: 'h1', // H1 contains the product name directly
        priceSelector: '.price, .cost, .amount, .money',
        stockSelector: '.add-to-cart, .cart-button, .shop-button',
        linkSelector: 'a[href*="/teeshop/"]', // Look for teeshop links in the same section
        imageSelector: '.product-image img, .item-image img, img[src*="product"], img[src*="tea"], img[src*="matcha"]',
        stockKeywords: ['add to cart', 'kaufen', 'in den warenkorb', 'verfügbar'],
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
      'poppatea': {
        name: 'Poppatea',
        baseUrl: 'https://poppatea.com',
        categoryUrl: 'https://poppatea.com/collections/all',
        productSelector: '.card, .product-card, .grid-item',
        nameSelector: 'h3, .card-title, [data-product-title], .product-title',
        priceSelector: '.price, .money',
        stockSelector: '.add-to-cart, .cart-button',
        linkSelector: 'a',
        imageSelector: 'img, .card-image img, .product-image img, img[src*="product"], img[src*="cdn/shop"]', // Updated to catch all images
        stockKeywords: ['add to cart', 'lägg i varukorg', 'köp'],
        outOfStockKeywords: ['slutsåld', 'ej i lager', 'sold out', 'notify me']
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
          rate: 0.0067 // 1 JPY = 0.0067 EUR (approximate, should be updated regularly)
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
          // Special handling for Sho-Cha site structure
          if (siteKey === 'sho-cha') {
            // For Sho-Cha, H1 elements contain product names, but links are separate
            const name = productElement.text().trim();
            
            // Skip if no valid name
            if (!name || name.length < 2) {
              continue;
            }
            
            // Find the corresponding teeshop link - improved strategy
            let productUrl = null;
            
            // Strategy 1: Look in immediate parent containers
            const immediateParent = productElement.parent();
            let teeshopLink = immediateParent.find('a[href*="/teeshop/"]').first();
            
            // Strategy 2: Look in wider container (section, div, article)
            if (!teeshopLink.length) {
              const section = productElement.closest('section, div, article, .product-container, .item-container');
              teeshopLink = section.find('a[href*="/teeshop/"]').first();
            }
            
            // Strategy 3: Look for sibling elements with teeshop links
            if (!teeshopLink.length) {
              teeshopLink = productElement.siblings().find('a[href*="/teeshop/"]').first();
            }
            
            // Strategy 4: Look in next/previous sibling containers
            if (!teeshopLink.length) {
              const nextElement = productElement.next();
              teeshopLink = nextElement.find('a[href*="/teeshop/"]').first();
              
              if (!teeshopLink.length) {
                const prevElement = productElement.prev();
                teeshopLink = prevElement.find('a[href*="/teeshop/"]').first();
              }
            }
            
            // Strategy 5: Find by matching product name patterns (improved)
            if (!teeshopLink.length) {
              const nameSlug = name.toLowerCase().replace(/[^a-z0-9]/g, '');
              const allTeeshopLinks = $('a[href*="/teeshop/"]');
              let bestMatch = null;
              let bestScore = 0;
              
              allTeeshopLinks.each((idx, link) => {
                const href = $(link).attr('href');
                const linkSlug = href.replace('/teeshop/', '').replace(/[^a-z0-9]/g, '');
                const linkText = $(link).text().toLowerCase().replace(/[^a-z0-9]/g, '');
                
                // Calculate match scores
                let score = 0;
                
                // Direct slug matching (higher score)
                const commonLength = Math.min(nameSlug.length, linkSlug.length);
                let commonChars = 0;
                for (let i = 0; i < commonLength; i++) {
                  if (nameSlug[i] === linkSlug[i]) {
                    commonChars++;
                  } else {
                    break;
                  }
                }
                score += (commonChars / nameSlug.length) * 10;
                
                // Check for key word matches
                const nameWords = name.toLowerCase().split(/\s+/).filter(w => w.length > 2);
                const linkWords = href.split(/[-_/]/).filter(w => w.length > 2);
                
                for (const nameWord of nameWords) {
                  for (const linkWord of linkWords) {
                    if (nameWord.includes(linkWord) || linkWord.includes(nameWord)) {
                      score += 5;
                    }
                  }
                }
                
                // Prefer shorter, more specific matches
                if (linkSlug.length > 0) {
                  score += (10 / linkSlug.length);
                }
                
                if (score > bestScore && score > 3) { // Minimum threshold
                  bestScore = score;
                  bestMatch = $(link);
                }
              });
              
              if (bestMatch) {
                teeshopLink = bestMatch;
              }
            }
            
            if (teeshopLink.length > 0) {
              productUrl = config.baseUrl + teeshopLink.attr('href');
            }
            
            if (productUrl) {
              // Create product object for Sho-Cha
              const productId = this.generateProductId(productUrl, name, siteKey);
              
              // Fetch price from individual product page
              let price = '';
              let priceValue = 0;
              try {
                const productResponse = await this.fetchWithRetry(productUrl);
                const product$ = cheerio.load(productResponse.data);
                
                // Extract price from product page - try multiple selectors
                const priceText = product$('.price, .product-price, .cost, .amount, [class*="price"], .currency, .money').first().text();
                if (priceText) {
                  price = this.cleanPriceBySite(priceText, siteKey);
                  priceValue = this.extractPriceValue(price);
                  this.logger.info('Extracted Sho-Cha price', { name, priceText, price, priceValue });
                }
              } catch (error) {
                this.logger.warn('Failed to fetch Sho-Cha product page for price', { productUrl, error: error.message });
              }
              
              // Try to extract image from the product page
              let imageUrl = null;
              try {
                imageUrl = await this.extractShoChaProductImage(productUrl, productId);
              } catch (error) {
                this.logger.warn('Failed to extract Sho-Cha product image', {
                  productUrl,
                  error: error.message
                });
              }
              
              const product = {
                id: productId,
                name: name,
                normalizedName: this.normalizeName(name),
                site: siteKey,
                siteName: config.name,
                price: price,
                originalPrice: price,
                priceValue: priceValue,
                currency: 'EUR',
                url: productUrl,
                imageUrl: imageUrl,
                isInStock: price ? true : false, // In stock if we found a price
                category: this.detectCategory(name, siteKey),
                lastChecked: new Date(),
                lastUpdated: new Date(),
                firstSeen: new Date(),
                isDiscontinued: false,
                missedScans: 0,
                crawlSource: 'cloud-run'
              };
              
              products.push(product);
              const wasUpdated = await this.saveProduct(product);
              if (wasUpdated) stockUpdates++;
            }
            
            continue; // Skip regular processing for Sho-Cha
          }
          
          // Regular processing for other sites
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
          let isInStock = this.determineStockStatusFromListing(productElement, config, siteKey);
          
          // For Horiishichimeien, check individual product page for accurate stock status
          if (siteKey === 'horiishichimeien' && productUrl) {
            try {
              isInStock = await this.checkHoriishichimeienStock(productUrl);
            } catch (error) {
              this.logger.warn('Failed to check Horiishichimeien stock on product page', {
                productUrl,
                error: error.message
              });
              // Fall back to listing page detection
            }
          }

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
        // Check for image alt attribute first
        if (found.is('img') && found.attr('alt')) {
          const altText = found.attr('alt').trim();
          if (altText) return altText;
        }
        
        // Then check for text content
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
  /**
   * Get current exchange rates and convert to EUR
   */
  async convertToEUR(amount, fromCurrency) {
    if (!amount || fromCurrency === 'EUR') {
      return amount;
    }

    // Fixed exchange rates (should be updated regularly in production)
    const exchangeRates = {
      'USD': 0.85,    // 1 USD = 0.85 EUR
      'CAD': 0.63,    // 1 CAD = 0.63 EUR  
      'JPY': 0.0067,  // 1 JPY = 0.0067 EUR
      'GBP': 1.17,    // 1 GBP = 1.17 EUR
      'SEK': 0.086,   // 1 SEK = 0.086 EUR (for Poppatea)
      'DKK': 0.134,   // 1 DKK = 0.134 EUR
      'NOK': 0.085,   // 1 NOK = 0.085 EUR
    };

    const rate = exchangeRates[fromCurrency];
    if (!rate) {
      this.logger.warn('Unknown currency for conversion', { fromCurrency, amount });
      return amount;
    }

    const convertedAmount = amount * rate;
    this.logger.info('Currency conversion', { 
      amount, 
      fromCurrency, 
      rate, 
      convertedAmount: convertedAmount.toFixed(2) 
    });
    
    return parseFloat(convertedAmount.toFixed(2));
  }

  /**
   * Parse price text and extract currency and amount
   */
  parsePriceAndCurrency(priceText) {
    if (!priceText) return { amount: null, currency: 'EUR' };

    const cleaned = priceText.replace(/\s+/g, ' ').trim();
    
    // Currency patterns
    const patterns = [
      { regex: /€(\d+[.,]\d+)/, currency: 'EUR' },           // €12.50
      { regex: /(\d+[.,]\d+)\s*€/, currency: 'EUR' },        // 12.50€ or 5,00€
      { regex: /\$(\d+[.,]\d+)/, currency: 'USD' },          // $12.50
      { regex: /(\d+[.,]\d+)\s*USD/, currency: 'USD' },      // 12.50 USD
      { regex: /CAD\s*(\d+[.,]\d+)/, currency: 'CAD' },      // CAD 15.00
      { regex: /(\d+[.,]\d+)\s*CAD/, currency: 'CAD' },      // 15.00 CAD
      { regex: /¥(\d{1,3}(?:,\d{3})*(?:\.\d+)?)/i, currency: 'JPY' }, // ¥10,800 or ¥648
      { regex: /(\d{1,3}(?:,\d{3})*(?:\.\d+)?)\s*¥/i, currency: 'JPY' }, // 10800 ¥
      { regex: /(\d{1,3}(?:,\d{3})*(?:\.\d+)?)\s*JPY/i, currency: 'JPY' }, // 10800 JPY
      { regex: /£(\d+[.,]\d+)/, currency: 'GBP' },           // £12.50
      { regex: /(\d+(?:[.,]\d+)?)\s*kr\b/i, currency: 'SEK' },       // 160 kr (Poppatea)
      { regex: /(\d+[.,]\d+)\s*DKK/, currency: 'DKK' },      // 12.50 DKK
      { regex: /(\d+[.,]\d+)\s*NOK/, currency: 'NOK' },      // 12.50 NOK
    ];

    for (const pattern of patterns) {
      const match = cleaned.match(pattern.regex);
      if (match) {
        const amountStr = match[1].replace(',', '.');
        const amount = parseFloat(amountStr);
        
        if (!isNaN(amount) && amount > 0) {
          return { amount, currency: pattern.currency };
        }
      }
    }

    // Fallback: try to extract any number and assume EUR
    const numberMatch = cleaned.match(/(\d+[.,]\d+)/);
    if (numberMatch) {
      const amountStr = numberMatch[1].replace(',', '.');
      const amount = parseFloat(amountStr);
      if (!isNaN(amount) && amount > 0) {
        return { amount, currency: 'EUR' };
      }
    }

    return { amount: null, currency: 'EUR' };
  }

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
    let numericValue = this.extractPriceValue(price);
    if (numericValue === null) {
      return price;
    }

    // Special handling for Horiishichimeien JPY cents
    if (siteKey === 'horiishichimeien' && config.currencyConversion.from === 'JPY') {
      // Shopify stores JPY prices in cents, so ¥648 is stored as 64800
      if (numericValue > 1000) {
        numericValue = numericValue / 100; // Convert cents to actual JPY
        this.logger.info('Converted JPY cents to JPY', { 
          original: numericValue * 100, 
          converted: numericValue,
          siteKey 
        });
      }
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
        // For Poppatea, check for Swedish out-of-stock indicators
        if (elementText.includes('slutsåld') || elementText.includes('ej i lager') || 
            elementText.includes('sold out') || elementText.includes('out of stock') ||
            elementText.includes('notify me') || elementText.includes('meddela mig')) return false;
        
        // Check for disabled/unavailable product indicators
        if (productElement.find('.product-unavailable, .variant-unavailable').length > 0) return false;
        
        // Check for price presence - Poppatea shows prices for available items
        const poppateaPriceElement = productElement.find(config.priceSelector);
        const priceText = poppateaPriceElement.text().trim();
        
        // If price contains "kr" and a number, it's likely in stock
        if (priceText.includes('kr') && /\d/.test(priceText)) {
          return true;
        }
        
        // Check if there's a valid product link (products without links might be unavailable)
        const hasValidLink = productElement.find('a[href*="/products/"]').length > 0;
        
        return hasValidLink && priceText !== '';

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
        
        // If price contains "¥" and a number, it's likely in stock
        if (hpriceText.includes('¥') && /\d/.test(hpriceText)) {
          return true;
        }
        
        // Check if there's a visible link to the product (products without links might be unavailable)
        const hasProductLink = productElement.find('a[href*="/products/"]').length > 0;
        
        // Product is in stock if it has a valid link and some price indication
        // Be more lenient - if there's a link and no explicit "sold out", consider it in stock
        return hasProductLink;

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
        lower.includes('chawan') || lower.includes('scoop') || lower.includes('chashaku') ||
        lower.includes('schale') || lower.includes('becher') || lower.includes('tasse') || 
        lower.includes('teebecher') || lower.includes('teeschale') || lower.includes('schüssel') || 
        lower.includes('teeschüssel')) {
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

    // Handle multi-currency strings like "¥2,000$13.57€11.66£10.04¥97.06"
    // Extract EUR price first if present
    const eurMatch = priceString.match(/€(\d+[.,]?\d*)/);
    if (eurMatch) {
      const eurValue = parseFloat(eurMatch[1].replace(',', '.'));
      return eurValue > 0 ? eurValue : null;
    }

    // Handle Japanese Yen (no decimal places, may have comma thousands separator)
    if (priceString.includes('¥') || priceString.includes('￥')) {
      // For multi-currency strings, extract only the first Yen value
      const yenMatch = priceString.match(/[¥￥](\d+(?:,\d{3})*)/);
      if (yenMatch) {
        const cleaned = yenMatch[1].replace(/,/g, '');
        const jpyValue = parseInt(cleaned);
        return jpyValue > 0 ? jpyValue : null;
      }
      
      // Fallback for simple Yen extraction
      const cleaned = priceString.replace(/[¥￥]/g, '').replace(/[^\d]/g, '');
      const jpyValue = parseInt(cleaned);
      return jpyValue > 0 ? jpyValue : null;
    }

    // Handle European format with comma as decimal separator
    if (/\d+,\d{2}/.test(priceString)) {
      const cleaned = priceString.replace(/[€$£]/g, '').replace(/[^\d,]/g, '');
      const euroValue = parseFloat(cleaned.replace(',', '.'));
      return euroValue > 0 ? euroValue : null;
    }

    // Handle standard format with period as decimal separator
    const cleaned = priceString.replace(/[€$¥£￥]/g, '').replace(/[^\d.]/g, '');
    
    // Extract the first number with decimal places
    const priceMatch = cleaned.match(/(\d+)\.(\d+)/);
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
        // Enhanced to handle both comma-separated (¥1,000) and non-comma (¥100) prices
        let jpyMatchIppodo = cleaned.match(/¥(\d{1,3}(?:,\d{3})*)/); // With comma separator
        if (!jpyMatchIppodo) {
          jpyMatchIppodo = cleaned.match(/¥(\d+)/); // Without comma separator for small amounts
        }
        
        if (jpyMatchIppodo) {
          const jpyValue = parseFloat(jpyMatchIppodo[1].replace(/,/g, ''));
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
        // Handle German Euro formatting: "5,00€" or "24,00 €"
        cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
        const shoChaEuroMatch = cleaned.match(/(\d+(?:,\d{2})?)\s*€/);
        if (shoChaEuroMatch) {
          const price = parseFloat(shoChaEuroMatch[1].replace(',', '.'));
          return `€${price.toFixed(2)}`;
        }
        
        // Try USD format and convert
        const shoChaUsdMatch = cleaned.match(/\$(\d+(?:\.\d{2})?)/);
        if (shoChaUsdMatch) {
          const usdValue = parseFloat(shoChaUsdMatch[1]);
          const euroValue = (usdValue * 0.85).toFixed(2); // Updated exchange rate
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
        // Handle Swedish Krona format (XXX kr) with improved parsing
        cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
        cleaned = cleaned.replace(/Ordinarie pris|Försäljningspris|Från|Enhetspris|per|Rea|Slutpris|Kampanjpris/gi, '');
        
        // Enhanced SEK parsing for better accuracy
        const poppateaKrMatch = cleaned.match(/(\d+(?:[.,]\d+)?)\s*kr/i);
        if (poppateaKrMatch) {
          const sekValue = parseFloat(poppateaKrMatch[1].replace(',', '.'));
          const euroValue = (sekValue * 0.086).toFixed(2); // Updated rate: 1 SEK = 0.086 EUR
          return `€${euroValue}`;
        }
        
        // Handle Euro format as fallback (for international customers)
        const poppateaEurMatch = cleaned.match(/€?\s*(\d+[,.]\d{2})\s*€?/);
        if (poppateaEurMatch) {
          const price = poppateaEurMatch[1].replace(',', '.');
          return `€${price}`;
        }
        
        // Handle whole number prices (common for Poppatea)
        const poppateaWholeMatch = cleaned.match(/(\d+)\s*kr/i);
        if (poppateaWholeMatch) {
          const sekValue = parseFloat(poppateaWholeMatch[1]);
          const euroValue = (sekValue * 0.086).toFixed(2);
          return `€${euroValue}`;
        }
        
        // Final fallback for any number format
        const simpleMatch = cleaned.match(/€?\s*(\d+)\s*€?/);
        if (simpleMatch) {
          return `€${simpleMatch[1]}.00`;
        }
        break;

      case 'yoshien':
        // Handle multi-currency strings like "¥2,000$13.57€11.66£10.04¥97.06"
        // Extract ONLY the EUR price to avoid confusion
        const yoshienEurMatch = cleaned.match(/€(\d+[.,]\d*)/);
        if (yoshienEurMatch) {
          const priceText = yoshienEurMatch[1].replace(',', '.');
          return `€${priceText}`;
        }
        
        // If no EUR found, try extracting the first Yen price and convert
        const yoshienYenMatch = cleaned.match(/¥(\d{1,3}(?:,\d{3})*)/);
        if (yoshienYenMatch) {
          const jpyValue = parseFloat(yoshienYenMatch[1].replace(/,/g, ''));
          const euroValue = (jpyValue * 0.0067).toFixed(2);
          return `€${euroValue}`;
        }
        
        // Fallback: clean up and extract any price
        cleaned = cleaned.replace('Ab ', '').trim();
        const yoshienFallbackMatch = cleaned.match(/(\d+[.,]\d+)\s*€/);
        if (yoshienFallbackMatch) {
          return yoshienFallbackMatch[1] + ' €';
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
        // Basic EUR handling for Enjoyemeri
        cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
        const enjoyEmeriMatch = cleaned.match(/€(\d+[.,]\d*)/);
        if (enjoyEmeriMatch) {
          const priceText = enjoyEmeriMatch[1].replace(',', '.');
          return `€${priceText}`;
        }
        break;

      case 'horiishichimeien':
        // For Horiishichimeien, handle Japanese Yen prices and convert to Euro
        // Remove duplicate prices and extra text
        cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
        cleaned = cleaned.replace(/Regular price|Sale price|Unit price|per|Sale|Sold out|JPY/gi, '');
        
        // Extract only the first valid Yen price to avoid duplicates
        // Fix: Handle comma-separated thousands properly (¥10,800 should be 10800, not 10)
        let horiYenMatch = cleaned.match(/¥(\d{1,3}(?:,\d{3})+)/); // With comma separator for thousands
        if (horiYenMatch) {
          const jpyValue = parseFloat(horiYenMatch[1].replace(/,/g, '')); // Remove commas: "10,800" -> 10800
          const euroValue = (jpyValue * 0.0065).toFixed(2); // Updated more accurate JPY to EUR rate
          return `€${euroValue}`;
        }
        
        // Handle prices without comma separator (for amounts under 1000)
        horiYenMatch = cleaned.match(/¥(\d+)(?!\d)/); // Ensure we don't partial match longer numbers
        if (horiYenMatch) {
          const jpyValue = parseFloat(horiYenMatch[1]);
          const euroValue = (jpyValue * 0.0065).toFixed(2);
          return `€${euroValue}`;
        }
        
        // Handle format without currency symbol (assume JPY if Japanese site)
        const horiNumMatch = cleaned.match(/(\d{1,3}(?:,\d{3})+|\d+)/);
        if (horiNumMatch) {
          const jpyValue = parseFloat(horiNumMatch[1].replace(/,/g, ''));
          const euroValue = (jpyValue * 0.0065).toFixed(2);
          return `€${euroValue}`;
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
      let foundInJson = false;

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

      // Method 1: Look for window.ShopifyAnalytics meta (common in newer Shopify themes)
      const shopifyAnalyticsScript = $('script:contains("window.ShopifyAnalytics")').html();
      if (shopifyAnalyticsScript && shopifyAnalyticsScript.includes('product')) {
        try {
          // Extract product data from ShopifyAnalytics
          const productMatch = shopifyAnalyticsScript.match(/var meta = ({.*?});/s);
          if (productMatch) {
            const metaData = JSON.parse(productMatch[1]);
            if (metaData.product && metaData.product.variants) {
              this.logger.info('Found product variants in ShopifyAnalytics', { 
                productUrl, 
                variantCount: metaData.product.variants.length 
              });
              
              for (const variant of metaData.product.variants) {
                const sizeName = variant.name || variant.title || variant.option1 || '';
                const variantName = sizeName ? `${baseName} - ${sizeName}` : baseName;
                
                // Calculate product ID for this variant
                const variantId = this.generateProductId(productUrl, variantName, 'poppatea');
                
                const variantProduct = {
                  id: variantId,
                  name: variantName.trim(),
                  normalizedName: this.normalizeName(variantName),
                  site: 'poppatea',
                  siteName: config.name,
                  price: variant.price !== undefined && variant.price !== null ? `€${(variant.price / 100).toFixed(2).replace('.', ',')}` : '',
                  originalPrice: variant.price !== undefined && variant.price !== null ? `€${(variant.price / 100).toFixed(2).replace('.', ',')}` : '',
                  priceValue: variant.price !== undefined && variant.price !== null ? variant.price / 100 : 0,
                  currency: 'EUR',
                  url: productUrl,
                  imageUrl: processedMainImageUrl,
                  isInStock: true, // Default to true, will be checked individually
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
          }
        } catch (e) {
          this.logger.warn('Failed to parse ShopifyAnalytics meta', { error: e.message });
        }
      }

      // Method 2: Look for Shopify product JSON (most reliable)
      if (!foundInJson) {
        const scriptTags = $('script[type="application/json"], script:contains("variants"), script:contains("product")');
        
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
                  price: variant.price !== undefined && variant.price !== null ? `€${(variant.price / 100).toFixed(2).replace('.', ',')}` : '',
                  originalPrice: variant.price !== undefined && variant.price !== null ? `€${(variant.price / 100).toFixed(2).replace('.', ',')}` : '',
                  priceValue: variant.price !== undefined && variant.price !== null ? variant.price / 100 : 0,
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
      }

      // Method 3: Look for variant selectors (HTML forms)
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
        method: foundInJson ? 'JSON' : 'HTML',
        withPrices: variants.filter(v => v.priceValue > 0).length,
        variantNames: variants.map(v => v.name).slice(0, 3)
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
    // Common patterns for Poppatea variants: "50g - €12.50", "100g / €25.00", "50g - 160 kr"
    const patterns = [
      /(\d+g)\s*[-\/]\s*€(\d+[,.]?\d*)/,        // "50g - €12.50"
      /(\d+g)\s*\(\s*€(\d+[,.]?\d*)\)/,         // "50g (€12.50)"
      /(\d+g)\s*€(\d+[,.]?\d*)/,                // "50g €12.50"
      /(\d+g)\s*[-\/]\s*(\d+)\s*kr/i,           // "50g - 160 kr" (Swedish Krona)
      /(\d+g)\s*\(\s*(\d+)\s*kr\)/i,           // "50g (160 kr)"
      /(\d+g)\s*(\d+)\s*kr/i,                  // "50g 160 kr"
      /(\d+\s*ml)\s*[-\/]\s*€(\d+[,.]?\d*)/,   // For liquid products
      /(\d+\s*ml)\s*[-\/]\s*(\d+)\s*kr/i,      // For liquid products in SEK
    ];

    for (const pattern of patterns) {
      const match = text.match(pattern);
      if (match) {
        const size = match[1];
        let price = match[2].replace(',', '.');
        let currency = 'EUR';
        
        // Check if this is Swedish Krona and convert to EUR
        if (text.toLowerCase().includes('kr')) {
          const sekValue = parseFloat(price);
          const euroValue = (sekValue * 0.085).toFixed(2); // 1 SEK = 0.085 EUR
          price = euroValue;
          currency = 'EUR';
        }
        
        return {
          name: `${baseName} (${size})`,
          normalizedName: this.normalizeName(`${baseName} ${size}`),
          price: `€${price}`,
          originalPrice: `€${price}`,
          priceValue: parseFloat(price),
          currency: currency
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

      // Validate URL format before attempting download
      try {
        new URL(absoluteUrl);
      } catch (urlError) {
        this.logger.warn('Invalid image URL format', { productId, siteKey, imageUrl: absoluteUrl });
        return null;
      }

      this.logger.info('Downloading image', { 
        productId, 
        siteKey, 
        imageUrl: absoluteUrl 
      });

      // Download image with improved error handling
      const response = await axios({
        method: 'GET',
        url: absoluteUrl,
        responseType: 'arraybuffer',
        timeout: 20000, // Increased timeout
        maxRedirects: 5,
        headers: {
          'User-Agent': this.userAgent,
          'Accept': 'image/*',
        }
      });

      // Validate response
      if (!response.data || response.data.length === 0) {
        this.logger.warn('Empty image response', { productId, siteKey, imageUrl: absoluteUrl });
        return null;
      }

      // Check if response is actually an image
      const contentType = response.headers['content-type'];
      if (contentType && !contentType.startsWith('image/')) {
        this.logger.warn('Response is not an image', { 
          productId, 
          siteKey, 
          imageUrl: absoluteUrl, 
          contentType 
        });
        return null;
      }

      // Compress image using Sharp with better error handling
      let compressedImageBuffer;
      try {
        compressedImageBuffer = await sharp(response.data)
          .resize(400, 400, { 
            fit: 'inside', 
            withoutEnlargement: true 
          })
          .jpeg({ 
            quality: 85,
            progressive: true 
          })
          .toBuffer();
      } catch (sharpError) {
        this.logger.warn('Failed to process image with Sharp', {
          productId,
          siteKey,
          imageUrl: absoluteUrl,
          error: sharpError.message
        });
        return null;
      }

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
          // Handle relative URLs
          if (imageUrl.startsWith('//')) {
            imageUrl = 'https:' + imageUrl;
          } else if (imageUrl.startsWith('/')) {
            imageUrl = config.baseUrl + imageUrl;
          } else if (!imageUrl.startsWith('http')) {
            // Relative path without leading slash
            imageUrl = config.baseUrl + '/' + imageUrl;
          }
          
          // Handle Shopify image templates
          if (imageUrl.includes('{width}x')) {
            imageUrl = imageUrl.replace(/_{width}x/, '');
            this.logger.info('Fixed Shopify image template', { 
              original: img.attr('src') || img.attr('data-src'), 
              fixed: imageUrl,
              siteKey 
            });
          }
          
          // Remove query parameters for cleaner URLs
          imageUrl = imageUrl.split('?')[0];
          
          // Validate URL format
          try {
            new URL(imageUrl);
            return imageUrl;
          } catch (e) {
            this.logger.warn('Invalid image URL format', { imageUrl, siteKey });
            continue;
          }
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

  /**
   * Fetch with retry mechanism for improved reliability
   */
  async fetchWithRetry(url, maxRetries = 3) {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const response = await axios.get(url, this.requestConfig);
        return response;
      } catch (error) {
        this.logger.warn('Fetch attempt failed', {
          url,
          attempt,
          maxRetries,
          error: error.message
        });
        
        if (attempt === maxRetries) {
          throw error;
        }
        
        // Wait before retrying (exponential backoff)
        await this.delay(Math.pow(2, attempt) * 1000);
      }
    }
  }

  async extractShoChaProductImage(productUrl, productId) {
    try {
      const response = await this.fetchWithRetry(productUrl);
      const $ = cheerio.load(response.data);
      
      // Enhanced image selectors for Sho-Cha
      const imageSelectors = [
        '.product-image img',
        '.shop-image img',
        '.main-image img',
        '.product-photo img',
        '.gallery img',
        '.product-media img',
        '.image-gallery img',
        'img[src*="product"]',
        'img[src*="matcha"]',
        'img[src*="tea"]',
        'img[alt*="matcha" i]',
        'img[alt*="tea" i]',
        'img[alt*="grün" i]', // German for green
        '.product-detail img',
        '.shop-detail img',
        // Fallback: any large images that might be product images
        'img[width][height]'
      ];
      
      for (const selector of imageSelectors) {
        const img = $(selector).first();
        if (img.length) {
          let imgSrc = img.attr('src') || img.attr('data-src') || img.attr('data-original') || img.attr('data-lazy');
          
          if (imgSrc) {
            // Skip placeholder, data URLs, and very small images
            if (imgSrc.includes('data:') || 
                imgSrc.includes('placeholder') || 
                imgSrc.includes('blank') ||
                imgSrc.includes('spacer') ||
                imgSrc.includes('pixel')) {
              continue;
            }
            
            // Check image dimensions to avoid tiny images
            const width = img.attr('width') || img.css('width');
            const height = img.attr('height') || img.css('height');
            if (width && height) {
              const w = parseInt(width);
              const h = parseInt(height);
              if (!isNaN(w) && !isNaN(h) && (w < 50 || h < 50)) {
                continue; // Skip very small images
              }
            }
            
            // Make absolute URL
            if (imgSrc.startsWith('//')) {
              imgSrc = 'https:' + imgSrc;
            } else if (imgSrc.startsWith('/')) {
              imgSrc = 'https://www.sho-cha.com' + imgSrc;
            } else if (!imgSrc.startsWith('http')) {
              imgSrc = 'https://www.sho-cha.com/' + imgSrc;
            }
            
            // Validate URL format
            try {
              new URL(imgSrc);
            } catch (e) {
              this.logger.warn('Invalid image URL format', { imgSrc, productUrl });
              continue;
            }
            
            // Download and store the image
            const processedImageUrl = await this.downloadAndStoreImage(imgSrc, productId, 'sho-cha');
            if (processedImageUrl) {
              this.logger.info('Successfully extracted Sho-Cha product image', {
                productUrl,
                productId,
                selector,
                originalUrl: imgSrc,
                processedUrl: processedImageUrl
              });
              return processedImageUrl;
            }
          }
        }
      }
      
      this.logger.info('No suitable product image found for Sho-Cha product', { productUrl, productId });
      return null;
      
    } catch (error) {
      this.logger.warn('Failed to extract Sho-Cha product image from page', {
        productUrl,
        productId,
        error: error.message
      });
      return null;
    }
  }

  async checkHoriishichimeienStock(productUrl) {
    try {
      const response = await this.fetchWithRetry(productUrl);
      const $ = cheerio.load(response.data);
      
      // First check for explicit sold out indicators
      const soldOutSelectors = [
        '.price__badge--sold-out',
        '.sold-out-badge',
        '.out-of-stock',
        '.badge--sold-out',
        ':contains("Sold out")',
        ':contains("Out of stock")',
        ':contains("売り切れ")',
        ':contains("Unavailable")',
        '.product-form--disabled'
      ];
      
      for (const selector of soldOutSelectors) {
        if ($(selector).length > 0) {
          this.logger.info('Found sold out indicator', { productUrl, selector });
          return false;
        }
      }
      
      // Check page text for sold out indicators
      const pageText = $('body').text().toLowerCase();
      if (pageText.includes('sold out') || 
          pageText.includes('out of stock') || 
          pageText.includes('unavailable') ||
          pageText.includes('売り切れ')) {
        this.logger.info('Found sold out text in page content', { productUrl });
        return false;
      }
      
      // Check for add to cart button or product form (positive indicators)
      const addToCartSelectors = [
        '.product-form__buttons button:not([disabled])',
        '.product-form button[name="add"]:not([disabled])',
        'form[action="/cart/add"] button:not([disabled])',
        '.btn--add-to-cart:not([disabled])',
        'button:contains("Add to cart"):not([disabled])',
        'button:contains("カートに入れる"):not([disabled])',
        '.shopify-payment-button button:not([disabled])',
        '.product-form__add-to-cart:not([disabled])'
      ];
      
      for (const selector of addToCartSelectors) {
        const button = $(selector);
        if (button.length > 0) {
          const buttonText = button.text().toLowerCase();
          if (!buttonText.includes('sold out') && 
              !buttonText.includes('out of stock') && 
              !buttonText.includes('unavailable') &&
              !buttonText.includes('売り切れ')) {
            this.logger.info('Found available add to cart button', { productUrl, buttonText: buttonText.substring(0, 50) });
            return true;
          }
        }
      }
      
      // Check for product variants (another positive indicator)
      const variantSelector = $('select[name="id"] option[value]:not([disabled]), input[name="id"]:not([disabled])');
      if (variantSelector.length > 0) {
        this.logger.info('Found available product variants', { productUrl, variantCount: variantSelector.length });
        return true;
      }
      
      // Check for price presence (products without prices are often unavailable)
      const priceSelectors = [
        '.price__regular .money',
        '.price .money',
        '.price-item--regular',
        '.product-price'
      ];
      
      for (const selector of priceSelectors) {
        const priceElement = $(selector);
        if (priceElement.length > 0) {
          const priceText = priceElement.text().trim();
          if (priceText && (priceText.includes('¥') || priceText.includes('JPY')) && /\d/.test(priceText)) {
            this.logger.info('Found valid price, assuming in stock', { productUrl, price: priceText });
            return true;
          }
        }
      }
      
      // If we can't determine stock status clearly, default to in stock
      // (better to have false positives than miss available products)
      this.logger.info('Could not determine stock status clearly, defaulting to in stock', { productUrl });
      return true;
      
    } catch (error) {
      this.logger.warn('Failed to check Horiishichimeien stock status', {
        productUrl,
        error: error.message
      });
      // Default to in stock on error to avoid missing products
      return true;
    }
  }
}

module.exports = CrawlerService;