const axios = require('axios');
const cheerio = require('cheerio');
const { v4: uuidv4 } = require('uuid');

/**
 * Sazentea specialized crawler
 * Handles German/European tea site structure
 */
class SazenteaSpecializedCrawler {
  constructor(logger) {
    this.logger = logger;
    this.baseUrl = 'https://sazentea.de';
    
    // Default request configuration
    this.requestConfig = {
      timeout: 30000,
      headers: {
        'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept-Encoding': 'gzip, deflate',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache'
      }
    };
  }

  async crawl(categoryUrl, config) {
    return await this.crawlProducts(categoryUrl, config);
  }

  async crawlProducts(categoryUrl = null, config = null) {
    const targetUrl = categoryUrl || 'https://sazentea.de/collections/matcha';

    try {
      const response = await axios.get(targetUrl, this.requestConfig);
      const $ = cheerio.load(response.data);

      const products = [];
      
      // Try multiple product selectors for Sazentea
      const productSelectors = [
        '.product-item',
        '.product-card',
        '.collection-product-card',
        '.grid-product__content',
        '.product-block'
      ];

      let productElements = $();
      for (const selector of productSelectors) {
        productElements = $(selector);
        if (productElements.length > 0) {
          this.logger.info('Found Sazentea products with selector', {
            selector,
            count: productElements.length
          });
          break;
        }
      }

      if (productElements.length === 0) {
        this.logger.warn('No products found with any selector');
        return { products: [], errors: [] };
      }

      for (let i = 0; i < productElements.length; i++) {
        const productElement = $(productElements[i]);
        
        try {
          const productData = await this.extractProductData($, productElement, i);
          
          if (productData) {
            this.logger.info('Extracted Sazentea product', {
              id: productData.id,
              name: productData.name,
              price: productData.price,
              priceValue: productData.priceValue,
              isInStock: productData.isInStock,
              url: productData.url
            });
            
            products.push(productData);
          }
        } catch (error) {
          this.logger.error('Failed to extract Sazentea product', {
            index: i,
            error: error.message
          });
        }
      }

      return {
        products: products,
        errors: []
      };
    } catch (error) {
      this.logger.error('Sazentea category page crawl failed', {
        url: targetUrl,
        error: error.message
      });
      throw error;
    }
  }

  async extractProductData($, productElement, index) {
    // Extract product name
    let name = '';
    
    const nameSelectors = [
      '.product-item__title',
      '.product-card__title',
      '.product-title',
      '.grid-product__title',
      'h3',
      'h4',
      '.h4',
      'a[href*="/products/"]'
    ];
    
    name = this.extractTextWithSelectors($, productElement, nameSelectors);
    
    // Try image alt text as fallback
    if (!name) {
      const imgElement = productElement.find('img').first();
      if (imgElement.length > 0) {
        const altText = imgElement.attr('alt');
        if (altText && altText.trim().length > 3) {
          name = altText.trim();
        }
      }
    }

    if (!name || name.length < 2) {
      this.logger.warn('No valid product name found', { index });
      return null;
    }

    // Extract product URL
    let productUrl = null;
    const linkElement = productElement.find('a[href*="/products/"]:first').first();
    
    if (linkElement.length > 0) {
      const href = linkElement.attr('href');
      if (href) {
        productUrl = href.startsWith('http') ? href : this.baseUrl + href;
      }
    }

    if (!productUrl) {
      this.logger.warn('No product URL found', { name, index });
      return null;
    }

    // Extract price - handle German/European formatting
    const priceSelectors = [
      '.price--current',
      '.product-item__price',
      '.product-card__price',
      '.price-item',
      '.price'
    ];
    
    let rawPrice = this.extractTextWithSelectors($, productElement, priceSelectors);

    // Clean and process price
    const { cleanedPrice, priceValue } = this.processPrice(rawPrice);

    // Extract image URL
    let imageUrl = null;
    const imageSelectors = [
      '.product-item__image img',
      '.product-card__image img',
      '.grid-product__image img',
      'img[src*="products/"]'
    ];
    
    for (const selector of imageSelectors) {
      const element = productElement.find(selector).first();
      if (element.length > 0) {
        const src = element.attr('src') || element.attr('data-src') || element.attr('data-srcset');
        if (src) {
          let processedSrc = src;
          if (processedSrc.includes('?')) {
            processedSrc = processedSrc.split('?')[0];
          }
          imageUrl = processedSrc.startsWith('//') ? 'https:' + processedSrc : processedSrc;
          break;
        }
      }
    }

    // Determine stock status
    const isInStock = this.determineStockStatus($, productElement);

    // Generate product ID
    const productId = this.generateProductId(productUrl, name);
    const currentTimestamp = new Date();

    return {
      id: productId,
      name: this.cleanProductName(name),
      normalizedName: this.normalizeName(this.cleanProductName(name)),
      site: 'sazentea',
      siteName: 'Sazen Tea',
      price: cleanedPrice,
      originalPrice: cleanedPrice,
      priceValue: priceValue,
      currency: 'EUR',
      url: productUrl,
      imageUrl: imageUrl,
      isInStock: isInStock,
      isDiscontinued: false,
      missedScans: 0,
      category: this.detectCategory(name),
      crawlSource: 'cloud-run',
      firstSeen: currentTimestamp,
      lastChecked: currentTimestamp,
      lastUpdated: currentTimestamp,
      lastPriceHistoryUpdate: currentTimestamp
    };
  }

  extractTextWithSelectors($, element, selectors) {
    for (const selector of selectors) {
      const found = element.find(selector).first();
      if (found.length > 0) {
        const text = found.text().replace(/\n+/g, ' ').replace(/\s+/g, ' ').trim();
        if (text && text.length > 2) {
          return text;
        }
      }
    }
    return '';
  }

  processPrice(rawPrice) {
    if (!rawPrice) {
      return { cleanedPrice: '', priceValue: null };
    }

    // Clean the price string
    let cleaned = rawPrice.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();
    cleaned = cleaned.replace(/Angebotspreis|Normaler Preis|Ab |ab |From/gi, '');
    
    // German price format: "19,00 €" or "€19,00"
    const germanPriceMatch = cleaned.match(/€?(\d+,\d{2})\s*€?|€(\d+\.\d{2})/);
    if (germanPriceMatch) {
      const priceText = (germanPriceMatch[1] || germanPriceMatch[2]).replace(',', '.');
      const priceValue = parseFloat(priceText);
      
      if (!isNaN(priceValue)) {
        return {
          cleanedPrice: `€${priceValue.toFixed(2)}`,
          priceValue: priceValue
        };
      }
    }
    
    // Standard EUR format: "€25.00" or "25.00€"
    const eurMatch = cleaned.match(/€(\d+\.?\d{0,2})|(\d+\.?\d{0,2})\s*€/);
    if (eurMatch) {
      const priceValue = parseFloat(eurMatch[1] || eurMatch[2]);
      
      if (!isNaN(priceValue)) {
        return {
          cleanedPrice: `€${priceValue.toFixed(2)}`,
          priceValue: priceValue
        };
      }
    }
    
    // Generic numeric value (assume EUR for German site)
    const numericMatch = cleaned.match(/(\d+\.?\d{0,2})/);
    if (numericMatch) {
      const numericValue = parseFloat(numericMatch[1]);
      if (!isNaN(numericValue) && numericValue > 1) {
        return {
          cleanedPrice: `€${numericValue.toFixed(2)}`,
          priceValue: numericValue
        };
      }
    }

    return { cleanedPrice: '', priceValue: null };
  }

  determineStockStatus($, productElement) {
    const elementText = productElement.text().toLowerCase();
    
    // Check for out of stock indicators (German)
    const outOfStockKeywords = ['ausverkauft', 'nicht verfügbar', 'sold out', 'out of stock'];
    for (const keyword of outOfStockKeywords) {
      if (elementText.includes(keyword)) {
        return false;
      }
    }
    
    // Check for in stock indicators
    const inStockKeywords = ['in den warenkorb', 'kaufen', 'add to cart', 'verfügbar'];
    for (const keyword of inStockKeywords) {
      if (elementText.includes(keyword)) {
        return true;
      }
    }
    
    // Check for product form elements
    const stockSelectors = [
      '.product-form',
      '.add-to-cart:not(.disabled)',
      'button[type="submit"]:not(.disabled)',
      '.btn--add-to-cart'
    ];
    
    for (const selector of stockSelectors) {
      if (productElement.find(selector).length > 0) {
        return true;
      }
    }
    
    // Default: assume in stock if price is present
    return productElement.find('.price').length > 0;
  }

  cleanProductName(name) {
    return name
      .replace(/\n+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .replace(/^(Matcha|Bio)\s+/i, '')  // Remove leading Matcha/Bio
      .replace(/\s+(Tee|Tea|Pulver|Powder)$/i, '')   // Remove trailing descriptors
      .trim();
  }

  detectCategory(name) {
    const lower = name.toLowerCase();

    if (lower.includes('premium') || lower.includes('grade a')) {
      return 'Premium Matcha';
    }

    if (lower.includes('bio') || lower.includes('organic')) {
      return 'Organic Matcha';
    }

    if (lower.includes('ceremonial') || lower.includes('zeremoniell')) {
      return 'Ceremonial Matcha';
    }

    if (lower.includes('cooking') || lower.includes('culinary') || lower.includes('küche')) {
      return 'Culinary Matcha';
    }

    if (lower.includes('set') || lower.includes('starter') || lower.includes('kit')) {
      return 'Tea Sets';
    }

    if (lower.includes('zubehör') || lower.includes('tool') || lower.includes('whisk') || 
        lower.includes('bowl') || lower.includes('schale') || lower.includes('besen')) {
      return 'Accessories';
    }

    return 'Matcha'; // Default fallback
  }

  normalizeName(name) {
    return name
      .toLowerCase()
      .replace(/[^\w\s]/g, '') // Remove special characters
      .replace(/\s+/g, ' ') // Normalize whitespace
      .trim();
  }

  generateProductId(url, name) {
    const urlPart = url.split('/').pop().split('?')[0] || '';
    const namePart = name.toLowerCase().replace(/[^a-z0-9]/g, '').substring(0, 20);
    return `sazentea_${urlPart}_${namePart}`.replace(/[^a-z0-9_]/g, '');
  }
}

module.exports = SazenteaSpecializedCrawler;
