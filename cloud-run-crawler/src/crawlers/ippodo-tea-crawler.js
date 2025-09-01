const axios = require('axios');
const cheerio = require('cheerio');
const { v4: uuidv4 } = require('uuid');

/**
 * Ippodo Tea specialized crawler
 * Handles international Shopify site with multiple currencies
 */
class IppodoTeaSpecializedCrawler {
  constructor(logger) {
    this.logger = logger;
    this.baseUrl = 'https://global.ippodo-tea.co.jp';
    
    // Default request configuration
    this.requestConfig = {
      timeout: 30000,
      headers: {
        'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,ja;q=0.8',
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
    const targetUrl = categoryUrl || 'https://global.ippodo-tea.co.jp/collections/matcha';

    try {
      const response = await axios.get(targetUrl, this.requestConfig);
      const $ = cheerio.load(response.data);

      const products = [];
      
      // Shopify product selectors for Ippodo
      const productSelectors = [
        '.product-item',
        '.grid-product__content',
        '.product-card',
        '.collection-product-card'
      ];

      let productElements = $();
      for (const selector of productSelectors) {
        productElements = $(selector);
        if (productElements.length > 0) {
          this.logger.info('Found Ippodo Tea products with selector', {
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
            this.logger.info('Extracted Ippodo Tea product', {
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
          this.logger.error('Failed to extract Ippodo Tea product', {
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
      this.logger.error('Ippodo Tea category page crawl failed', {
        url: targetUrl,
        error: error.message
      });
      throw error;
    }
  }

  async extractProductData($, productElement, index) {
    // Extract product name - try multiple methods for Shopify structure
    let name = '';
    
    const nameSelectors = [
      '.product-item__title',
      '.grid-product__title',
      '.product-card__title',
      '.h4',
      'h3',
      'h4',
      '.product-title',
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

    // Extract price - handle multiple currency formats
    const priceSelectors = [
      '.price--current',
      '.product-item__price',
      '.grid-product__price',
      '.price-item',
      '.price'
    ];
    
    let rawPrice = this.extractTextWithSelectors($, productElement, priceSelectors);

    // Clean and process price with currency conversion
    const { cleanedPrice, priceValue } = this.processPrice(rawPrice);

    // Extract image URL
    let imageUrl = null;
    const imageSelectors = [
      '.product-item__image img',
      '.grid-product__image img',
      '.product-card__image img',
      'img[src*="products/"]'
    ];
    
    for (const selector of imageSelectors) {
      const element = productElement.find(selector).first();
      if (element.length > 0) {
        const src = element.attr('src') || element.attr('data-src') || element.attr('data-srcset');
        if (src) {
          // Handle Shopify image URLs
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

    return {
      id: productId,
      name: this.cleanProductName(name),
      price: cleanedPrice,
      priceValue: priceValue,
      url: productUrl,
      imageUrl: imageUrl,
      isInStock: isInStock,
      category: this.detectCategory(name),
      lastUpdated: new Date().toISOString()
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
    cleaned = cleaned.replace(/Sale price|Regular price|From/gi, '');
    
    // Handle multiple currency formats that Ippodo might use
    
    // USD format: "$25.00" or "25.00 USD"
    const usdMatch = cleaned.match(/\$(\d+\.?\d{0,2})|(\d+\.?\d{0,2})\s*USD/i);
    if (usdMatch) {
      const priceValue = parseFloat(usdMatch[1] || usdMatch[2]);
      if (!isNaN(priceValue)) {
        // Convert USD to EUR (approximate rate)
        const eurValue = priceValue * 0.92;
        return {
          cleanedPrice: `€${eurValue.toFixed(2)} ($${priceValue.toFixed(2)})`,
          priceValue: eurValue
        };
      }
    }
    
    // JPY format: "¥2,500" or "2500円"
    const jpyMatch = cleaned.match(/¥([\d,]+)|([\d,]+)円/);
    if (jpyMatch) {
      const priceText = (jpyMatch[1] || jpyMatch[2]).replace(/,/g, '');
      const jpyValue = parseInt(priceText);
      if (!isNaN(jpyValue)) {
        // Convert JPY to EUR using corrected rate
        const eurValue = jpyValue * 0.0058;
        return {
          cleanedPrice: `€${eurValue.toFixed(2)} (¥${jpyValue.toLocaleString()})`,
          priceValue: eurValue
        };
      }
    }
    
    // EUR format: "€15.00" or "15,00€"
    const eurMatch = cleaned.match(/€(\d+[.,]?\d{0,2})|(\d+[.,]?\d{0,2})\s*€/);
    if (eurMatch) {
      const priceText = (eurMatch[1] || eurMatch[2]).replace(',', '.');
      const eurValue = parseFloat(priceText);
      if (!isNaN(eurValue)) {
        return {
          cleanedPrice: `€${eurValue.toFixed(2)}`,
          priceValue: eurValue
        };
      }
    }
    
    // Generic numeric value (assume USD if no currency symbol)
    const numericMatch = cleaned.match(/(\d+\.?\d{0,2})/);
    if (numericMatch) {
      const numericValue = parseFloat(numericMatch[1]);
      if (!isNaN(numericValue) && numericValue > 1) {
        // Assume USD and convert to EUR
        const eurValue = numericValue * 0.92;
        return {
          cleanedPrice: `€${eurValue.toFixed(2)} (~$${numericValue.toFixed(2)})`,
          priceValue: eurValue
        };
      }
    }

    return { cleanedPrice: '', priceValue: null };
  }

  determineStockStatus($, productElement) {
    const elementText = productElement.text().toLowerCase();
    
    // Check for out of stock indicators
    const outOfStockKeywords = ['sold out', 'out of stock', 'unavailable', '売切れ'];
    for (const keyword of outOfStockKeywords) {
      if (elementText.includes(keyword)) {
        return false;
      }
    }
    
    // Check for in stock indicators
    const inStockKeywords = ['add to cart', 'buy now', 'in stock', 'available'];
    for (const keyword of inStockKeywords) {
      if (elementText.includes(keyword)) {
        return true;
      }
    }
    
    // Check for Shopify product form elements
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
      .replace(/^(Matcha|抹茶)\s+/i, '')  // Remove leading Matcha
      .replace(/\s+(Tea|Powder)$/i, '')   // Remove trailing Tea/Powder
      .trim();
  }

  detectCategory(name) {
    const lower = name.toLowerCase();

    if (lower.includes('premium') || lower.includes('superior')) {
      return 'Premium Matcha';
    }

    if (lower.includes('standard') || lower.includes('regular')) {
      return 'Standard Matcha';
    }

    if (lower.includes('organic') || lower.includes('bio')) {
      return 'Organic Matcha';
    }

    if (lower.includes('ceremony') || lower.includes('ceremonial')) {
      return 'Ceremonial Matcha';
    }

    if (lower.includes('cooking') || lower.includes('culinary')) {
      return 'Culinary Matcha';
    }

    if (lower.includes('set') || lower.includes('kit')) {
      return 'Tea Sets';
    }

    if (lower.includes('tool') || lower.includes('whisk') || lower.includes('bowl')) {
      return 'Accessories';
    }

    return 'Matcha'; // Default fallback
  }

  generateProductId(url, name) {
    const urlPart = url.split('/').pop().split('?')[0] || '';
    const namePart = name.toLowerCase().replace(/[^a-z0-9]/g, '').substring(0, 20);
    return `ippodo_${urlPart}_${namePart}`.replace(/[^a-z0-9_]/g, '');
  }
}

module.exports = IppodoTeaSpecializedCrawler;
