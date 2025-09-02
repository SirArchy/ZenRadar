const axios = require('axios');
const cheerio = require('cheerio');
const { v4: uuidv4 } = require('uuid');

/**
 * Horiishichimeien specialized crawler
 * Handles Japanese Yen prices and complex Shopify structure
 */
class HoriishichimeienSpecializedCrawler {
  constructor(logger) {
    this.logger = logger;
    this.baseUrl = 'https://horiishichimeien.com';
    
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
    
    // JPY to EUR exchange rate (consistent with main crawler service)
    this.jpyToEurRate = 0.00577;
  }

  async crawl(categoryUrl, config) {
    return await this.crawlProducts(categoryUrl, config);
  }

  async crawlProducts(categoryUrl = null, config = null) {
    const targetUrl = categoryUrl || this.categoryUrl || 'https://horiishichimeien.com/en/collections/all?selected=%E6%8A%B9%E8%8C%B6';

    try {
      const response = await axios.get(targetUrl, this.requestConfig);
      const $ = cheerio.load(response.data);

      const products = [];
      const productElements = $('.grid__item');
      
      this.logger.info('Found Horiishichimeien product containers', {
        count: productElements.length
      });

      for (let i = 0; i < productElements.length; i++) {
        const productElement = $(productElements[i]);
        
        try {
          const productData = await this.extractProductData($, productElement, i);
          
          if (productData) {
            this.logger.info('Extracted Horiishichimeien product', {
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
          this.logger.error('Failed to extract Horiishichimeien product', {
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
      this.logger.error('Horiishichimeien category page crawl failed', {
        url: targetUrl,
        error: error.message
      });
      throw error;
    }
  }

  async extractProductData($, productElement, index) {
    // Extract product name using multiple selectors
    const nameSelectors = [
      'a[href*="/products/"] span.visually-hidden',
      '.card__heading',
      '.product-title',
      'a[href*="/products/"]'
    ];
    
    let name = this.extractTextWithSelectors($, productElement, nameSelectors);
    
    if (!name || name.length < 2) {
      this.logger.warn('No valid product name found', { index });
      return null;
    }

    // Extract product URL
    const linkElement = productElement.find('a[href*="/products/"]').first();
    let productUrl = null;
    
    if (linkElement.length > 0) {
      const href = linkElement.attr('href');
      productUrl = href.startsWith('http') ? href : this.baseUrl + href;
    }

    if (!productUrl) {
      this.logger.warn('No product URL found', { name, index });
      return null;
    }

    // Extract price using multiple selectors
    const priceSelectors = [
      '.price__regular .money',
      '.price .money',
      '.price-item--regular',
      '.money'
    ];
    
    let rawPrice = this.extractTextWithSelectors($, productElement, priceSelectors);
    
    // If no price found on listing page, try to get it from product page
    if (!rawPrice || !rawPrice.includes('¥')) {
      try {
        rawPrice = await this.fetchPriceFromProductPage(productUrl);
      } catch (error) {
        this.logger.warn('Failed to fetch price from product page', {
          url: productUrl,
          error: error.message
        });
      }
    }

    // Clean and convert price
    const { cleanedPrice, priceValue } = this.processPrice(rawPrice);

    // Extract image URL
    const imageElement = productElement.find('.grid-view-item__image, .lazyload, img[src*="products/"], .product-image img').first();
    let imageUrl = null;
    
    if (imageElement.length > 0) {
      const src = imageElement.attr('src') || imageElement.attr('data-src');
      if (src) {
        imageUrl = src.startsWith('//') ? 'https:' + src : src;
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

  async fetchPriceFromProductPage(productUrl) {
    try {
      const response = await axios.get(productUrl, this.requestConfig);
      const $ = cheerio.load(response.data);
      
      // Try multiple price selectors on product page
      const priceSelectors = [
        '.price__current .money',
        '.price .money',
        '.product-price .money',
        '.price-item--regular',
        '[data-price]',
        '.money'
      ];
      
      for (const selector of priceSelectors) {
        const priceElement = $(selector).first();
        if (priceElement.length > 0) {
          const price = priceElement.text().trim();
          if (price && price.includes('¥')) {
            return price;
          }
        }
      }
      
      // Fallback: search for price patterns in page text
      const pageText = $('body').text();
      const priceMatch = pageText.match(/¥(\d{1,3}(?:,\d{3})*)/);
      if (priceMatch) {
        return `¥${priceMatch[1]}`;
      }
      
      return null;
    } catch (error) {
      this.logger.error('Failed to fetch product page', {
        url: productUrl,
        error: error.message
      });
      return null;
    }
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
    cleaned = cleaned.replace(/Regular price|Sale price|Unit price|per|Sale|Sold out|JPY|from/gi, '');
    
    // Extract JPY price
    const yenMatch = cleaned.match(/¥(\d{1,3}(?:,\d{3})*)/);
    if (yenMatch) {
      const jpyValue = parseFloat(yenMatch[1].replace(/,/g, ''));
      const euroValue = jpyValue * this.jpyToEurRate;
      
      return {
        cleanedPrice: `€${euroValue.toFixed(2)}`,
        priceValue: parseFloat(euroValue.toFixed(2))
      };
    }
    
    // Fallback: try to extract just numbers
    const numberMatch = cleaned.match(/(\d{1,3}(?:,\d{3})*)/);
    if (numberMatch) {
      const jpyValue = parseFloat(numberMatch[1].replace(/,/g, ''));
      const euroValue = jpyValue * this.jpyToEurRate;
      
      return {
        cleanedPrice: `€${euroValue.toFixed(2)}`,
        priceValue: parseFloat(euroValue.toFixed(2))
      };
    }

    return { cleanedPrice: '', priceValue: null };
  }

  determineStockStatus($, productElement) {
    const elementText = productElement.text().toLowerCase();
    
    // Check for out of stock indicators
    const outOfStockKeywords = ['sold out', 'unavailable', '売り切れ', 'out of stock'];
    for (const keyword of outOfStockKeywords) {
      if (elementText.includes(keyword)) {
        return false;
      }
    }
    
    // Check for stock form elements
    const stockSelectors = [
      '.product-form__buttons',
      '.product-form',
      'form[action="/cart/add"]',
      'button[name="add"]'
    ];
    
    for (const selector of stockSelectors) {
      if (productElement.find(selector).length > 0) {
        return true;
      }
    }
    
    // Default: assume in stock if price is present
    return productElement.find('.money, .price').length > 0;
  }

  cleanProductName(name) {
    return name
      .replace(/\n+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .replace(/^(Matcha|Tea)\s+/i, '')  // Remove leading Matcha/Tea
      .trim();
  }

  detectCategory(name) {
    const lower = name.toLowerCase();

    if (lower.includes('whisk') || lower.includes('chasen') || lower.includes('bowl') || 
        lower.includes('chawan') || lower.includes('scoop') || lower.includes('chashaku')) {
      return 'Accessories';
    }

    if (lower.includes('set') || lower.includes('kit')) {
      return 'Tea Sets';
    }

    if (lower.includes('hojicha') || lower.includes('houjicha')) {
      return 'Hojicha';
    }

    if (lower.includes('genmaicha')) {
      return 'Genmaicha';
    }

    if (lower.includes('sencha')) {
      return 'Sencha';
    }

    if (lower.includes('gyokuro')) {
      return 'Gyokuro';
    }

    if (lower.includes('matcha')) {
      if (lower.includes('ceremonial') || lower.includes('ceremony')) {
        return 'Ceremonial Matcha';
      }
      if (lower.includes('premium') || lower.includes('grade a')) {
        return 'Premium Matcha';
      }
      if (lower.includes('cooking') || lower.includes('culinary')) {
        return 'Culinary Matcha';
      }
      return 'Matcha';
    }

    return 'Matcha'; // Default fallback
  }

  generateProductId(url, name) {
    const urlPart = url.split('/').pop().split('?')[0] || '';
    const namePart = name.toLowerCase().replace(/[^a-z0-9]/g, '').substring(0, 20);
    return `horiishichimeien_${urlPart}_${namePart}`.replace(/[^a-z0-9_]/g, '');
  }
}

module.exports = HoriishichimeienSpecializedCrawler;
