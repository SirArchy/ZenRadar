const axios = require('axios');
const cheerio = require('cheerio');

/**
 * Sho-Cha specific crawler
 * Handles the complex structure of sho-cha.com
 */
class ShoChaSpecializedCrawler {
  constructor(logger) {
    this.logger = logger;
    this.baseUrl = 'https://www.sho-cha.com';
    
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

  async crawl(categoryUrl, config) {
    return await this.crawlProducts(categoryUrl, config);
  }

  async crawlProducts(categoryUrl = null, config = null) {
    const targetUrl = categoryUrl || this.categoryUrl || 'https://www.sho-cha.com/teeshop';
    try {
      const response = await axios.get(targetUrl, this.requestConfig);
      const $ = cheerio.load(response.data);

      const products = [];

      // Find all teeshop links that might lead to product pages
      const productLinks = [];
      $('a[href*="/teeshop/"]').each((_, link) => {
        const href = $(link).attr('href');
        if (href && !href.endsWith('/teeshop') && !productLinks.includes(href)) {
          productLinks.push(href.startsWith('http') ? href : this.baseUrl + href);
        }
      });

      this.logger.info('Found Sho-Cha product links', { 
        count: productLinks.length,
        links: productLinks.slice(0, 5) // Log first 5 for debugging
      });

      // Process each product link
      for (const productUrl of productLinks) {
        try {
          const product = await this.extractProductFromPage(productUrl);
          if (product && product.name && product.price) {
            products.push(product);
          }
        } catch (error) {
          this.logger.warn('Failed to extract Sho-Cha product', {
            url: productUrl,
            error: error.message
          });
        }
      }

      return {
        products: products,
        errors: []
      };
    } catch (error) {
      this.logger.error('Sho-Cha category page crawl failed', {
        url: this.categoryUrl,
        error: error.message
      });
      throw error;
    }
  }

  async extractProductFromPage(productUrl) {
    try {
      const response = await axios.get(productUrl, this.requestConfig);
      const $ = cheerio.load(response.data);

      // Extract product name from page title, h1, or specific selectors
      let name = '';
      const nameSelectors = [
        'h1',
        '.product-title',
        '.main-title',
        'title'
      ];

      for (const selector of nameSelectors) {
        const element = $(selector).first();
        if (element.length) {
          let text = element.text().trim();
          // Clean up title text
          if (selector === 'title') {
            text = text.replace(/\s*-\s*Sho-Cha.*$/i, '');
            text = text.replace(/\s*\|\s*.*$/i, '');
          }
          if (text && text.length > 2) {
            name = text;
            break;
          }
        }
      }

      if (!name) {
        this.logger.warn('No product name found', { url: productUrl });
        return null;
      }

      // Extract price from various possible locations
      let price = '';
      const priceSelectors = [
        '.price',
        '.cost',
        '.amount',
        '.money',
        '.product-price',
        '.price-current',
        '[class*="price"]',
        '[class*="cost"]'
      ];

      for (const selector of priceSelectors) {
        const priceElements = $(selector);
        priceElements.each((_, element) => {
          const text = $(element).text().trim();
          // Look for Euro prices
          if (text.includes('€') && text.match(/\d/)) {
            price = text;
            return false; // Break out of each loop
          }
        });
        if (price) break;
      }

      // If no € price found, look for any price pattern
      if (!price) {
        const pageText = $('body').text();
        const priceMatches = pageText.match(/€\s*\d+[.,]?\d*/g) || 
                           pageText.match(/\d+[.,]?\d*\s*€/g);
        if (priceMatches && priceMatches.length > 0) {
          price = priceMatches[0];
        }
      }

      // Clean and validate price
      price = this.cleanShoChaPrice(price);
      
      if (!price) {
        this.logger.warn('No price found for Sho-Cha product', { 
          url: productUrl, 
          name 
        });
        return null;
      }

      // Determine stock status
      const pageText = $('body').text().toLowerCase();
      const isInStock = !pageText.includes('ausverkauft') && 
                       !pageText.includes('nicht verfügbar') && 
                       !pageText.includes('sold out') &&
                       !$('.sold-out, .out-of-stock').length;

      // Extract image
      let imageUrl = null;
      const imageSelectors = [
        '.product-image img',
        '.main-image img',
        '.gallery img',
        'img[src*="product"]',
        'img[src*="matcha"]',
        'img[src*="tea"]',
        'img[alt*="matcha" i]',
        'img[alt*="tea" i]'
      ];

      for (const selector of imageSelectors) {
        const img = $(selector).first();
        if (img.length) {
          const src = img.attr('src') || img.attr('data-src');
          if (src) {
            imageUrl = src.startsWith('http') ? src : this.baseUrl + src;
            
            // Clean up the URL and ensure it's properly encoded
            if (imageUrl) {
              // Remove any extra parameters that might cause issues
              imageUrl = imageUrl.split('?')[0];
              
              // Ensure proper URL encoding for special characters
              try {
                // Decode first in case it's double-encoded, then encode properly
                const decoded = decodeURIComponent(imageUrl);
                imageUrl = encodeURI(decoded);
              } catch (e) {
                // If there's an encoding error, use the original URL
                this.logger.warn('URL encoding error for image', { 
                  originalUrl: imageUrl, 
                  error: e.message 
                });
              }
            }
            break;
          }
        }
      }

      // Generate product ID
      const urlPart = productUrl.split('/').pop() || '';
      const namePart = name.toLowerCase().replace(/[^a-z0-9]/g, '').substring(0, 20);
      const productId = `sho-cha_${urlPart}_${namePart}`.replace(/[^a-z0-9_]/g, '');

      const product = {
        id: productId,
        name: name,
        normalizedName: this.normalizeName(name),
        site: 'sho-cha',
        siteName: 'Sho-Cha',
        price: price,
        originalPrice: price,
        priceValue: this.extractPriceValue(price),
        currency: 'EUR',
        url: productUrl,
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

      this.logger.info('Extracted Sho-Cha product', {
        id: product.id,
        name: product.name,
        price: product.price,
        priceValue: product.priceValue,
        isInStock: product.isInStock,
        url: productUrl
      });

      return product;

    } catch (error) {
      this.logger.error('Failed to extract Sho-Cha product from page', {
        url: productUrl,
        error: error.message
      });
      throw error;
    }
  }

  cleanShoChaPrice(priceStr) {
    if (!priceStr) return '';

    let cleaned = priceStr.trim();
    
    // Remove newlines and normalize spaces
    cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
    
    // Handle German Euro formatting: "5,00€" or "24,00 €"
    const euroMatch = cleaned.match(/(\d+(?:,\d{2})?)\s*€/);
    if (euroMatch) {
      const price = parseFloat(euroMatch[1].replace(',', '.'));
      return `€${price.toFixed(2)}`;
    }
    
    // Try USD format and convert
    const usdMatch = cleaned.match(/\$(\d+(?:\.\d{2})?)/);
    if (usdMatch) {
      const usdValue = parseFloat(usdMatch[1]);
      const euroValue = (usdValue * 0.85).toFixed(2); // Updated exchange rate
      return `€${euroValue}`;
    }

    // Try to extract any price with € symbol
    const generalEuroMatch = cleaned.match(/€\s*(\d+[.,]?\d*)/);
    if (generalEuroMatch) {
      const price = parseFloat(generalEuroMatch[1].replace(',', '.'));
      return `€${price.toFixed(2)}`;
    }

    // Try reverse format (number first, then €)
    const reverseEuroMatch = cleaned.match(/(\d+[.,]?\d*)\s*€/);
    if (reverseEuroMatch) {
      const price = parseFloat(reverseEuroMatch[1].replace(',', '.'));
      return `€${price.toFixed(2)}`;
    }

    return '';
  }

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

  normalizeName(name) {
    return name
      .toLowerCase()
      .replace(/[^\w\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  detectCategory(name) {
    const lower = name.toLowerCase();

    // Check for accessories first
    if (lower.includes('whisk') || lower.includes('chasen') || lower.includes('bowl') || 
        lower.includes('chawan') || lower.includes('scoop') || lower.includes('chashaku') ||
        lower.includes('schale') || lower.includes('becher') || lower.includes('tasse') || 
        lower.includes('teebecher') || lower.includes('teeschale')) {
      return 'Accessories';
    }

    // Check for tea sets
    if (lower.includes('set') || lower.includes('kit')) {
      return 'Tea Sets';
    }

    // Other tea types
    if (lower.includes('genmaicha')) return 'Genmaicha';
    if (lower.includes('hojicha')) return 'Hojicha';
    if (lower.includes('black tea') || lower.includes('earl grey')) return 'Black Tea';

    // Matcha variants
    if (lower.includes('matcha')) {
      if (lower.includes('ceremonial') || lower.includes('ceremony')) return 'Ceremonial Matcha';
      if (lower.includes('premium') || lower.includes('grade a')) return 'Premium Matcha';
      if (lower.includes('cooking') || lower.includes('culinary')) return 'Culinary Matcha';
      return 'Matcha';
    }

    return 'Matcha'; // Default fallback
  }
}

module.exports = ShoChaSpecializedCrawler;
