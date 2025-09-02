const axios = require('axios');
const cheerio = require('cheerio');
const { v4: uuidv4 } = require('uuid');

/**
 * Matcha Kāru specialized crawler
 * Handles German website structure and pricing
 */
class MatchaKaruSpecializedCrawler {
  constructor(logger) {
    this.logger = logger;
    this.baseUrl = 'https://matcha-karu.com';
    
    // Default request configuration
    this.requestConfig = {
      timeout: 30000,
      headers: {
        'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7', // Prefer German
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
    const targetUrl = categoryUrl || 'https://matcha-karu.com/collections/matcha-tee';

    try {
      const response = await axios.get(targetUrl, this.requestConfig);
      const $ = cheerio.load(response.data);

      const products = [];
      const productElements = $('.product-item');
      
      this.logger.info('Found Matcha Kāru product containers', {
        count: productElements.length
      });

      for (let i = 0; i < productElements.length; i++) {
        const productElement = $(productElements[i]);
        
        try {
          const productData = await this.extractProductData($, productElement, i);
          
          if (productData) {
            this.logger.info('Extracted Matcha Kāru product', {
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
          this.logger.error('Failed to extract Matcha Kāru product', {
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
      this.logger.error('Matcha Kāru category page crawl failed', {
        url: targetUrl,
        error: error.message
      });
      throw error;
    }
  }

  async extractProductData($, productElement, index) {
    // Extract product name - try image alt text first, then link text
    let name = '';
    
    // Method 1: Try image alt text (often more descriptive)
    const imgElement = productElement.find('a[href*="/products/"] img').first();
    if (imgElement.length > 0) {
      const altText = imgElement.attr('alt');
      if (altText && altText.trim().length > 3) {
        name = altText.trim();
      }
    }
    
    // Method 2: Try link text as fallback
    if (!name) {
      const linkElement = productElement.find('a[href*="/products/"]:nth-of-type(2)').first();
      if (linkElement.length > 0) {
        name = linkElement.text().trim();
      }
    }
    
    // Method 3: Try any product link
    if (!name) {
      const anyLinkElement = productElement.find('a[href*="/products/"]').first();
      if (anyLinkElement.length > 0) {
        name = anyLinkElement.text().trim();
      }
    }

    if (!name || name.length < 2) {
      this.logger.warn('No valid product name found', { index });
      return null;
    }

    // Extract product URL
    const linkElement = productElement.find('a[href*="/products/"]:first').first();
    let productUrl = null;
    
    if (linkElement.length > 0) {
      const href = linkElement.attr('href');
      productUrl = href.startsWith('http') ? href : this.baseUrl + href;
    }

    if (!productUrl) {
      this.logger.warn('No product URL found', { name, index });
      return null;
    }

    // Extract price
    const priceSelectors = [
      '.price__current',
      '.price-item',
      '.price'
    ];
    
    let rawPrice = this.extractTextWithSelectors($, productElement, priceSelectors);

    // Clean and process price
    const { cleanedPrice, priceValue } = this.processPrice(rawPrice);

    // Extract image URL
    let imageUrl = null;
    const imageSelectors = [
      '.product-item__aspect-ratio img',
      '.product-item__image img',
      'img[src*="products/"]'
    ];
    
    for (const selector of imageSelectors) {
      const element = productElement.find(selector).first();
      if (element.length > 0) {
        const src = element.attr('src') || element.attr('data-src');
        if (src) {
          imageUrl = src.startsWith('//') ? 'https:' + src : src;
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
      site: 'matcha-karu',
      siteName: 'Matcha-Karu',
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

    // Clean the price string for German formatting
    let cleaned = rawPrice.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();
    cleaned = cleaned.replace(/Angebotspreis|Ab |ab |Preis|EUR/gi, '');
    
    // German price format: "19,00 €" or "19,00€"
    const germanPriceMatch = cleaned.match(/(\d+,\d{2})\s*€/);
    if (germanPriceMatch) {
      const priceText = germanPriceMatch[1].replace(',', '.');
      const priceValue = parseFloat(priceText);
      
      return {
        cleanedPrice: `€${priceValue.toFixed(2)}`,
        priceValue: priceValue
      };
    }
    
    // Standard format: "€19.00" or "19.00€"
    const standardPriceMatch = cleaned.match(/€?(\d+\.?\d{0,2})\s*€?/);
    if (standardPriceMatch) {
      const priceValue = parseFloat(standardPriceMatch[1]);
      
      return {
        cleanedPrice: `€${priceValue.toFixed(2)}`,
        priceValue: priceValue
      };
    }

    return { cleanedPrice: '', priceValue: null };
  }

  determineStockStatus($, productElement) {
    const elementText = productElement.text().toLowerCase();
    
    // Check for out of stock indicators (German)
    const outOfStockKeywords = ['ausverkauft', 'nicht verfügbar', 'sold out'];
    for (const keyword of outOfStockKeywords) {
      if (elementText.includes(keyword)) {
        return false;
      }
    }
    
    // Check for in stock indicators
    const inStockKeywords = ['in den warenkorb', 'kaufen', 'add to cart', 'angebotspreis'];
    for (const keyword of inStockKeywords) {
      if (elementText.includes(keyword)) {
        return true;
      }
    }
    
    // Check for product form elements
    const stockSelectors = [
      '.product-form',
      '.add-to-cart:not(.disabled)',
      'button[type="submit"]'
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
      .trim();
  }

  detectCategory(name) {
    const lower = name.toLowerCase();

    if (lower.includes('zubehör') || lower.includes('schale') || lower.includes('besen') || 
        lower.includes('löffel') || lower.includes('whisk') || lower.includes('bowl')) {
      return 'Accessories';
    }

    if (lower.includes('set') || lower.includes('starter')) {
      return 'Tea Sets';
    }

    if (lower.includes('bio') || lower.includes('organic')) {
      return 'Organic Matcha';
    }

    if (lower.includes('matcha')) {
      if (lower.includes('ceremonial') || lower.includes('zeremoniell')) {
        return 'Ceremonial Matcha';
      }
      if (lower.includes('premium') || lower.includes('grade a')) {
        return 'Premium Matcha';
      }
      if (lower.includes('cooking') || lower.includes('culinary') || lower.includes('küche')) {
        return 'Culinary Matcha';
      }
      return 'Matcha';
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
    return `matchakaru_${urlPart}_${namePart}`.replace(/[^a-z0-9_]/g, '');
  }
}

module.exports = MatchaKaruSpecializedCrawler;
