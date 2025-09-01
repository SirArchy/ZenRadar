const axios = require('axios');
const cheerio = require('cheerio');
const { v4: uuidv4 } = require('uuid');

/**
 * Marukyu-Koyamaen specialized crawler
 * Handles Japanese website structure and JPY pricing
 */
class MarukyuKoyamaenSpecializedCrawler {
  constructor(logger) {
    this.logger = logger;
    this.baseUrl = 'https://www.marukyu-koyamaen.co.jp';
    
    // Default request configuration with appropriate headers for Japanese site
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
    const targetUrl = categoryUrl || 'https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha';

    try {
      const response = await axios.get(targetUrl, this.requestConfig);
      const $ = cheerio.load(response.data);

      const products = [];
      
      // Try multiple product selectors for Marukyu-Koyamaen
      const productSelectors = [
        '.product-list .product-item',
        '.product-item',
        'tr[data-product]',
        '.matcha-product',
        '.item-row'
      ];

      let productElements = $();
      for (const selector of productSelectors) {
        productElements = $(selector);
        if (productElements.length > 0) {
          this.logger.info('Found Marukyu-Koyamaen products with selector', {
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
            this.logger.info('Extracted Marukyu-Koyamaen product', {
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
          this.logger.error('Failed to extract Marukyu-Koyamaen product', {
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
      this.logger.error('Marukyu-Koyamaen category page crawl failed', {
        url: targetUrl,
        error: error.message
      });
      throw error;
    }
  }

  async extractProductData($, productElement, index) {
    // Extract product name - try multiple methods
    let name = '';
    
    // Method 1: Try product title/name cell
    const nameSelectors = [
      '.product-name',
      '.item-name',
      '.product-title',
      'td:nth-child(2)',  // Often second column in table structure
      'td:first-child',   // Sometimes first column
      'h3',
      'h4',
      '.title'
    ];
    
    name = this.extractTextWithSelectors($, productElement, nameSelectors);
    
    // Method 2: Try link text if no name found
    if (!name) {
      const linkElement = productElement.find('a').first();
      if (linkElement.length > 0) {
        name = linkElement.text().trim();
      }
    }

    if (!name || name.length < 2) {
      this.logger.warn('No valid product name found', { index });
      return null;
    }

    // Extract product URL
    let productUrl = null;
    const linkElement = productElement.find('a').first();
    
    if (linkElement.length > 0) {
      const href = linkElement.attr('href');
      if (href) {
        productUrl = href.startsWith('http') ? href : this.baseUrl + href;
      }
    }

    // If no direct URL, try to construct one from product name/ID
    if (!productUrl) {
      const productId = productElement.attr('data-product') || productElement.attr('id');
      if (productId) {
        productUrl = `${this.baseUrl}/english/shop/products/detail/${productId}`;
      }
    }

    // Extract price - specifically looking for JPY format
    const priceSelectors = [
      '.price',
      '.product-price', 
      '.item-price',
      'td:last-child',    // Often last column contains price
      'td:nth-last-child(2)', // Sometimes second to last
      '.yen'
    ];
    
    let rawPrice = this.extractTextWithSelectors($, productElement, priceSelectors);

    // Clean and process price with JPY conversion
    const { cleanedPrice, priceValue } = this.processPrice(rawPrice);

    // Extract image URL
    let imageUrl = null;
    const imageSelectors = [
      '.product-image img',
      '.item-image img',
      'img[src*="product"]',
      'img[src*="matcha"]'
    ];
    
    for (const selector of imageSelectors) {
      const element = productElement.find(selector).first();
      if (element.length > 0) {
        const src = element.attr('src') || element.attr('data-src');
        if (src) {
          imageUrl = src.startsWith('//') ? 'https:' + src : 
                    src.startsWith('/') ? this.baseUrl + src : src;
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
    
    // Japanese price format: "¥1,000" or "1,000円" or "1000 yen"
    const yenPatterns = [
      /¥([\d,]+)/,
      /([\d,]+)円/,
      /([\d,]+)\s*yen/i,
      /JPY\s*([\d,]+)/i,
      /([\d,]+)\s*JPY/i
    ];
    
    for (const pattern of yenPatterns) {
      const match = cleaned.match(pattern);
      if (match) {
        const priceText = match[1].replace(/,/g, '');
        const yenValue = parseInt(priceText);
        
        if (!isNaN(yenValue) && yenValue > 0) {
          // Convert JPY to EUR using the corrected exchange rate
          const eurValue = yenValue * 0.0058; // Updated exchange rate
          
          return {
            cleanedPrice: `€${eurValue.toFixed(2)} (¥${yenValue.toLocaleString()})`,
            priceValue: eurValue
          };
        }
      }
    }
    
    // Try to extract any numeric value as fallback
    const numericMatch = cleaned.match(/(\d+)/);
    if (numericMatch) {
      const numericValue = parseInt(numericMatch[1]);
      if (numericValue > 100) { // Likely JPY if large number
        const eurValue = numericValue * 0.0058;
        return {
          cleanedPrice: `€${eurValue.toFixed(2)} (¥${numericValue.toLocaleString()})`,
          priceValue: eurValue
        };
      }
    }

    return { cleanedPrice: '', priceValue: null };
  }

  determineStockStatus($, productElement) {
    const elementText = productElement.text().toLowerCase();
    
    // Check for out of stock indicators (Japanese/English)
    const outOfStockKeywords = ['sold out', '完売', '在庫切れ', 'out of stock'];
    for (const keyword of outOfStockKeywords) {
      if (elementText.includes(keyword)) {
        return false;
      }
    }
    
    // Check for in stock indicators
    const inStockKeywords = ['add to cart', 'buy now', '購入', 'in stock'];
    for (const keyword of inStockKeywords) {
      if (elementText.includes(keyword)) {
        return true;
      }
    }
    
    // Check for form elements
    const stockSelectors = [
      '.add-to-cart:not(.disabled)',
      'button[type="submit"]',
      '.buy-button'
    ];
    
    for (const selector of stockSelectors) {
      if (productElement.find(selector).length > 0) {
        return true;
      }
    }
    
    // Default: assume in stock if price is present
    return productElement.find('.price').length > 0 || 
           productElement.text().match(/¥|円|yen/i);
  }

  cleanProductName(name) {
    return name
      .replace(/\n+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .replace(/^(Matcha|抹茶)\s+/i, '')  // Remove leading Matcha
      .trim();
  }

  detectCategory(name) {
    const lower = name.toLowerCase();

    if (lower.includes('ceremonial') || lower.includes('ceremony') || lower.includes('茶道')) {
      return 'Ceremonial Matcha';
    }

    if (lower.includes('premium') || lower.includes('grade') || lower.includes('特級')) {
      return 'Premium Matcha';
    }

    if (lower.includes('cooking') || lower.includes('culinary') || lower.includes('料理')) {
      return 'Culinary Matcha';
    }

    if (lower.includes('organic') || lower.includes('bio') || lower.includes('有機')) {
      return 'Organic Matcha';
    }

    if (lower.includes('powder') || lower.includes('粉末')) {
      return 'Matcha Powder';
    }

    return 'Matcha'; // Default fallback
  }

  generateProductId(url, name) {
    if (url) {
      const urlPart = url.split('/').pop().split('?')[0] || '';
      const namePart = name.toLowerCase().replace(/[^a-z0-9]/g, '').substring(0, 20);
      return `marukyu_${urlPart}_${namePart}`.replace(/[^a-z0-9_]/g, '');
    } else {
      const namePart = name.toLowerCase().replace(/[^a-z0-9]/g, '').substring(0, 30);
      return `marukyu_${namePart}`.replace(/[^a-z0-9_]/g, '');
    }
  }
}

module.exports = MarukyuKoyamaenSpecializedCrawler;
