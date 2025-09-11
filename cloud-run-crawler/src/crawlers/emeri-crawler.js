/**
 * Emeri (Enjoy Emeri) specialized crawler
 * Handles the specific structure and requirements of enjoyemeri.com
 */
class EmeriSpecializedCrawler {
  constructor(logger) {
    this.logger = logger;
    this.name = 'Emeri';
    this.baseUrl = 'https://enjoyemeri.com';
    this.categoryUrl = 'https://www.enjoyemeri.com/collections/shop-all';
    
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
      const productElements = $(config.productSelector || '.product-card');
      
      this.logger.info('Found Emeri product containers', {
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
          const linkElement = productElement.find(config.linkSelector || 'a');
          if (linkElement.length) {
            const href = linkElement.attr('href');
            if (href) {
              productUrl = href.startsWith('http') ? href : this.baseUrl + href;
            }
          }

          // Extract price
          const priceElement = productElement.find(config.priceSelector || '.price');
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
            site: 'enjoyemeri',
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
          
          this.logger.info('Extracted Emeri product', {
            name: product.name,
            price: product.price,
            inStock: product.isInStock,
            url: product.url,
            imageUrl: product.imageUrl ? 'present' : 'missing'
          });

        } catch (error) {
          this.logger.warn('Failed to extract Emeri product', {
            containerIndex: i,
            error: error.message
          });
        }
      }

      this.logger.info('Emeri crawl completed', {
        productsFound: products.length
      });

      return { products };
    } catch (error) {
      this.logger.error('Emeri crawl failed', {
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

    // Handle Canadian dollar format
    if (/\$\d+\.?\d*/.test(priceString)) {
      const cleaned = priceString.replace(/[^\d.]/g, '');
      const cadValue = parseFloat(cleaned);
      if (cadValue > 0) {
        // Convert CAD to EUR (approximate rate)
        const eurValue = cadValue * 0.63;
        return parseFloat(eurValue.toFixed(2));
      }
    }

    // Handle European format
    if (/€\d+[.,]?\d*/.test(priceString)) {
      const cleaned = priceString.replace(/[€]/g, '').replace(',', '.').replace(/[^\d.]/g, '');
      const euroValue = parseFloat(cleaned);
      return euroValue > 0 ? euroValue : null;
    }

    return null;
  }

  /**
   * Get site configuration for Emeri
   */
  getConfig() {
    return {
      name: 'Emeri',
      baseUrl: this.baseUrl,
      categoryUrl: this.categoryUrl,
      productSelector: '.product-card',
      nameSelector: 'h3, .product-title',
      priceSelector: '.price',
      stockSelector: '.price',
      linkSelector: 'a',
      imageSelector: '.product-media__image, .product-card__image img',
      stockKeywords: ['add to cart', 'buy now', 'purchase'],
      outOfStockKeywords: ['out of stock', 'sold out'],
      currency: 'CAD',
      currencySymbol: '$'
    };
  }

  /**
   * Extract image URL from Emeri product element
   * Emeri uses Shopify structure with Canadian focus
   */
  extractImageUrl(productElement, config) {
    const selectors = [
      '.product-media__image img',
      '.product-card__image img',
      '.product-image img',
      '.card__media img',
      'img[src*="products/"]'
    ];
    
    for (const selector of selectors) {
      const img = productElement.find(selector).first();
      if (img.length) {
        let imageUrl = img.attr('src') || img.attr('data-src') || img.attr('data-original');
        
        // Handle lazy loading attributes
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
            this.logger.info('Extracted Emeri image URL', { 
              imageUrl, 
              selector,
              originalSrc: img.attr('src')
            });
            return imageUrl;
          } catch (e) {
            this.logger.warn('Invalid Emeri image URL format', { 
              imageUrl, 
              selector,
              error: e.message
            });
            continue;
          }
        }
      }
    }

    this.logger.warn('No valid image URL found for Emeri product');
    return null;
  }

  /**
   * Clean price text specific to Emeri format (CAD)
   */
  cleanPrice(priceText) {
    if (!priceText) return null;
    
    const cleaned = priceText.replace(/\s+/g, ' ').trim();
    
    // Look for CAD prices
    const cadMatch = cleaned.match(/\$\s*(\d+[.,]\d*)/);
    if (cadMatch) {
      const price = cadMatch[1].replace(',', '.');
      return `$${price}`;
    }
    
    // CAD with explicit currency
    const cadExplicitMatch = cleaned.match(/CAD\s*\$?\s*(\d+[.,]\d*)/);
    if (cadExplicitMatch) {
      const price = cadExplicitMatch[1].replace(',', '.');
      return `$${price}`;
    }
    
    // Fallback for numbers only (assume CAD)
    const numberMatch = cleaned.match(/(\d+[.,]\d+)/);
    if (numberMatch) {
      const price = numberMatch[1].replace(',', '.');
      return `$${price}`;
    }
    
    return null;
  }

  /**
   * Extract product name from Emeri elements
   */
  extractProductName(productElement) {
    const selectors = [
      'h3',
      '.product-title',
      '.product-card__title',
      '.card__heading',
      'h2'
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
   * Check stock status for Emeri products
   */
  checkStockStatus(productElement) {
    // Check for explicit out of stock indicators
    const outOfStockSelectors = [
      '.sold-out',
      '.out-of-stock',
      '.unavailable',
      ':contains("sold out")',
      ':contains("out of stock")',
      ':contains("unavailable")'
    ];
    
    for (const selector of outOfStockSelectors) {
      if (productElement.find(selector).length > 0) {
        return false;
      }
    }
    
    // Check for add to cart button
    const addToCartSelectors = [
      '.btn--add-to-cart',
      '.product-form__cart',
      'button[name="add"]',
      '.add-to-cart',
      '.product-form'
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
   * Generate product ID for Emeri products
   */
  generateProductId(url, name) {
    const urlPath = url.replace(this.baseUrl, '').replace(/^\//, '');
    const cleanName = name ? name.toLowerCase().replace(/[^a-z0-9]/g, '') : '';
    
    if (urlPath.includes('products/')) {
      const productSlug = urlPath.split('products/')[1].split('?')[0];
      return `emeri_${productSlug}_${cleanName}`.substring(0, 100);
    }
    
    return `emeri_${cleanName}`.substring(0, 100);
  }

  /**
   * Check if this is a matcha product based on name and URL
   */
  isMatchaProduct(name, url) {
    if (!name && !url) return false;
    
    const searchText = `${name || ''} ${url || ''}`.toLowerCase();
    const matchaKeywords = [
      'matcha',
      'green tea powder',
      'ceremonial grade',
      'premium grade',
      'culinary grade',
      'organic matcha'
    ];
    
    return matchaKeywords.some(keyword => searchText.includes(keyword));
  }
}

module.exports = EmeriSpecializedCrawler;
