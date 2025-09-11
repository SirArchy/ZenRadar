/**
 * Nakamura Tokichi specialized crawler
 * Handles the specific structure and requirements of global.tokichi.jp
 */
class NakamuraTokichiSpecializedCrawler {
  constructor(logger) {
    this.logger = logger;
    this.name = 'Nakamura Tokichi';
    this.baseUrl = 'https://global.tokichi.jp';
    this.categoryUrl = 'https://global.tokichi.jp/collections/matcha';
    
    // Default request configuration
    this.requestConfig = {
      timeout: 30000,
      headers: {
        'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache'
      }
    };
  }

  /**
   * Main crawl method that returns products array
   */
  async crawl(categoryUrl, config) {
    const axios = require('axios');
    const cheerio = require('cheerio');
    
    try {
      const targetUrl = categoryUrl || this.categoryUrl;
      const response = await axios.get(targetUrl, this.requestConfig);
      const $ = cheerio.load(response.data);

      const products = [];
      const productElements = $(config.productSelector || '.card-wrapper');
      
      this.logger.info('Found Nakamura Tokichi product containers', {
        count: productElements.length
      });

      for (let i = 0; i < productElements.length; i++) {
        const productElement = $(productElements[i]);
        
        try {
          // Extract product name
          const name = this.extractProductName(productElement);
          if (!name || !this.isMatchaProduct(name, '')) {
            continue;
          }

          // Extract product URL
          let productUrl = null;
          const linkElement = productElement.find(config.linkSelector || '.card__heading a');
          if (linkElement.length) {
            const href = linkElement.attr('href');
            if (href) {
              productUrl = href.startsWith('http') ? href : this.baseUrl + href;
            }
          }

          // Extract price
          const priceElement = productElement.find(config.priceSelector || '.price__current .price-item--regular');
          const rawPrice = priceElement.text().trim();
          const price = this.cleanPrice(rawPrice);

          // Check stock status
          const isInStock = this.checkStockStatus(productElement);

          // Generate product ID
          const productId = this.generateProductId(productUrl || targetUrl, name);

          // Extract image URL
          const imageUrl = this.extractImageUrl(productElement, config);

          const product = {
            id: productId,
            name: name,
            normalizedName: this.normalizeName(name),
            site: 'tokichi',
            siteName: this.name,
            price: price,
            originalPrice: price,
            priceValue: this.extractPriceValue(price),
            currency: 'EUR',
            url: productUrl || targetUrl,
            imageUrl: imageUrl,
            isInStock,
            category: this.detectCategory(name),
            lastChecked: new Date(),
            lastUpdated: new Date(),
            firstSeen: new Date(),
            isDiscontinued: false,
            missedScans: 0,
            crawlSource: 'cloud-run'
          };

          products.push(product);
          
          this.logger.info('Extracted Nakamura Tokichi product', {
            name: product.name,
            price: product.price,
            inStock: product.isInStock,
            url: product.url,
            imageUrl: product.imageUrl ? 'present' : 'missing'
          });

        } catch (error) {
          this.logger.warn('Failed to extract Nakamura Tokichi product', {
            containerIndex: i,
            error: error.message
          });
        }
      }

      this.logger.info('Nakamura Tokichi crawl completed', {
        productsFound: products.length
      });

      return { products };
    } catch (error) {
      this.logger.error('Nakamura Tokichi crawl failed', {
        error: error.message,
        categoryUrl
      });
      return { products: [] };
    }
  }

  /**
   * Normalize product name for better matching
   */
  normalizeName(name) {
    return name
      .toLowerCase()
      .replace(/[^\w\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * Detect product category
   */
  detectCategory(name) {
    const lower = name.toLowerCase();
    if (lower.includes('ceremonial') || lower.includes('ceremony')) return 'Ceremonial Matcha';
    if (lower.includes('premium') || lower.includes('grade a')) return 'Premium Matcha';
    if (lower.includes('cooking') || lower.includes('culinary')) return 'Culinary Matcha';
    return 'Matcha';
  }

  /**
   * Extract numeric price value from price string
   */
  extractPriceValue(priceString) {
    if (!priceString) return null;

    // Handle European format with comma as decimal separator
    if (/\d+,\d{2}/.test(priceString)) {
      const cleaned = priceString.replace(/[€$£]/g, '').replace(/[^\d,]/g, '');
      const euroValue = parseFloat(cleaned.replace(',', '.'));
      return euroValue > 0 ? euroValue : null;
    }

    // Handle standard format with period as decimal separator
    const cleaned = priceString.replace(/[€$¥£￥]/g, '').replace(/[^\d.]/g, '');
    const priceMatch = cleaned.match(/(\d+)\.(\d+)/);
    if (priceMatch) {
      const wholePart = parseInt(priceMatch[1]);
      const decimalPart = parseInt(priceMatch[2]) / 100;
      return wholePart + decimalPart;
    }

    const intMatch = cleaned.match(/(\d+)/);
    if (intMatch) {
      return parseInt(intMatch[1]);
    }

    return null;
  }

  /**
   * Get site configuration for Nakamura Tokichi
   */
  getConfig() {
    return {
      name: 'Nakamura Tokichi',
      baseUrl: this.baseUrl,
      categoryUrl: this.categoryUrl,
      productSelector: '.card-wrapper',
      nameSelector: '.card__heading a, .card__content .card__heading',
      priceSelector: '.price__current .price-item--regular, .price .price-item',
      stockSelector: '',
      linkSelector: '.card__heading a, .card__content a',
      imageSelector: '.card__media img, .card__inner img, img[alt*="matcha"]',
      stockKeywords: ['add to cart', 'add to bag', 'buy now'],
      outOfStockKeywords: ['out of stock', 'sold out'],
      currency: 'JPY',
      currencySymbol: '¥'
    };
  }

  /**
   * Extract image URL from Tokichi product element
   * Tokichi uses Shopify structure with specific image handling
   */
  extractImageUrl(productElement, config) {
    const selectors = [
      '.card__media img',
      '.card__inner img',
      'img[alt*="matcha"]',
      '.card-wrapper img',
      '.product-card__image img'
    ];
    
    for (const selector of selectors) {
      const img = productElement.find(selector).first();
      if (img.length) {
        let imageUrl = img.attr('src') || img.attr('data-src') || img.attr('data-original');
        
        // Handle lazy loading attributes specific to Shopify
        if (!imageUrl) {
          imageUrl = img.attr('data-lazy') || 
                    img.attr('data-srcset') || 
                    img.attr('srcset');
          
          if (imageUrl && imageUrl.includes(',')) {
            // Extract highest resolution from srcset
            const srcsetParts = imageUrl.split(',');
            const highestRes = srcsetParts[srcsetParts.length - 1].trim();
            imageUrl = highestRes.split(' ')[0];
          }
        }

        if (imageUrl) {
          // Handle relative URLs
          if (imageUrl.startsWith('//')) {
            imageUrl = 'https:' + imageUrl;
          } else if (imageUrl.startsWith('/')) {
            imageUrl = this.baseUrl + imageUrl;
          } else if (!imageUrl.startsWith('http')) {
            imageUrl = this.baseUrl + '/' + imageUrl;
          }
          
          // Handle Shopify image size parameters
          if (imageUrl.includes('_x.')) {
            imageUrl = imageUrl.replace(/_\d+x\./, '_800x.');
          }
          
          // Remove query parameters
          imageUrl = imageUrl.split('?')[0];
          
          // Validate URL format
          try {
            new URL(imageUrl);
            this.logger.info('Extracted Tokichi image URL', { 
              imageUrl, 
              selector,
              originalSrc: img.attr('src')
            });
            return imageUrl;
          } catch (e) {
            this.logger.warn('Invalid Tokichi image URL format', { 
              imageUrl, 
              selector,
              error: e.message
            });
            continue;
          }
        }
      }
    }

    this.logger.warn('No valid image URL found for Tokichi product');
    return null;
  }

  /**
   * Clean price text specific to Tokichi format
   */
  cleanPrice(priceText) {
    if (!priceText) return null;
    
    const cleaned = priceText.replace(/\s+/g, ' ').trim();
    
    // Look for JPY prices
    const jpyMatch = cleaned.match(/¥\s*(\d{1,3}(?:,\d{3})*)/);
    if (jpyMatch) {
      return `¥${jpyMatch[1]}`;
    }
    
    // USD prices
    const usdMatch = cleaned.match(/\$\s*(\d+[.,]\d*)/);
    if (usdMatch) {
      const price = usdMatch[1].replace(',', '.');
      return `$${price}`;
    }
    
    // Fallback for numbers only
    const numberMatch = cleaned.match(/(\d{1,3}(?:,\d{3})*)/);
    if (numberMatch) {
      return `¥${numberMatch[1]}`;
    }
    
    return null;
  }

  /**
   * Extract product name from Tokichi elements
   */
  extractProductName(productElement) {
    const selectors = [
      '.card__heading a',
      '.card__content .card__heading',
      '.card__heading',
      '.product-title',
      'h3 a'
    ];
    
    for (const selector of selectors) {
      const nameElement = productElement.find(selector);
      if (nameElement.length) {
        const name = nameElement.text().trim();
        if (name) {
          return name;
        }
      }
    }
    
    return null;
  }

  /**
   * Check stock status for Tokichi products
   */
  checkStockStatus(productElement) {
    // Check for explicit out of stock indicators
    const outOfStockSelectors = [
      '.sold-out',
      '.out-of-stock',
      '.price__badge--sold-out',
      ':contains("sold out")',
      ':contains("out of stock")'
    ];
    
    for (const selector of outOfStockSelectors) {
      if (productElement.find(selector).length > 0) {
        return false;
      }
    }
    
    // Check for add to cart button
    const addToCartSelectors = [
      '.product-form__cart',
      '.btn--add-to-cart',
      'button[name="add"]',
      '.add-to-cart'
    ];
    
    for (const selector of addToCartSelectors) {
      if (productElement.find(selector).length > 0) {
        return true;
      }
    }
    
    // If price is present, assume in stock
    const priceElement = productElement.find('.price');
    if (priceElement.length > 0 && priceElement.text().trim()) {
      return true;
    }
    
    return true; // Default to in stock
  }

  /**
   * Generate product ID for Tokichi products
   */
  generateProductId(url, name) {
    const urlPath = url.replace(this.baseUrl, '').replace(/^\//, '');
    const cleanName = name ? name.toLowerCase().replace(/[^a-z0-9]/g, '') : '';
    
    if (urlPath.includes('products/')) {
      const productSlug = urlPath.split('products/')[1].split('?')[0];
      return `tokichi_${productSlug}_${cleanName}`.substring(0, 100);
    }
    
    return `tokichi_${cleanName}`.substring(0, 100);
  }

  /**
   * Check if this is a matcha product based on name and URL
   */
  isMatchaProduct(name, url) {
    if (!name && !url) return false;
    
    const searchText = `${name || ''} ${url || ''}`.toLowerCase();
    const matchaKeywords = [
      'matcha',
      '抹茶',
      'green tea powder',
      'ceremonial',
      'premium'
    ];
    
    return matchaKeywords.some(keyword => searchText.includes(keyword));
  }
}

module.exports = NakamuraTokichiSpecializedCrawler;
