/**
 * Yoshien specialized crawler
 * Handles the specific structure and requirements of yoshien.com
 */
class YoshienSpecializedCrawler {
  constructor(logger) {
    this.logger = logger;
    this.name = 'Yoshi En';
    this.baseUrl = 'https://www.yoshien.com';
    this.categoryUrl = 'https://www.yoshien.com/matcha';
    
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
      const productElements = $(config.productSelector || '.cs-product-tile');
      
      this.logger.info('Found Yoshien product containers', {
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
          const linkElement = productElement.find(config.linkSelector || 'a.product-item-link');
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

          // Extract image URL and process it
          let imageUrl = null;
          try {
            const rawImageUrl = this.extractImageUrl(productElement, config);
            if (rawImageUrl) {
              imageUrl = await this.downloadAndStoreImage(rawImageUrl, productId, 'yoshien');
            }
          } catch (error) {
            this.logger.warn('Failed to process product image', {
              productId,
              error: error.message
            });
          }

          const product = {
            id: productId,
            name: name,
            normalizedName: this.normalizeName(name),
            site: 'yoshien',
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
          
          this.logger.info('Extracted Yoshien product', {
            name: product.name,
            price: product.price,
            inStock: product.isInStock,
            url: product.url,
            imageUrl: product.imageUrl ? 'present' : 'missing'
          });

        } catch (error) {
          this.logger.warn('Failed to extract Yoshien product', {
            containerIndex: i,
            error: error.message
          });
        }
      }

      this.logger.info('Yoshien crawl completed', {
        productsFound: products.length
      });

      return { products };
    } catch (error) {
      this.logger.error('Yoshien crawl failed', {
        error: error.message,
        categoryUrl
      });
      return { products: [] };
    }
  }

  /**
   * Get site configuration for Yoshien
   */
  getConfig() {
    return {
      name: 'Yoshi En',
      baseUrl: this.baseUrl,
      categoryUrl: this.categoryUrl,
      productSelector: '.cs-product-tile',
      nameSelector: 'a.product-item-link',
      priceSelector: '.price',
      stockSelector: '.price',
      linkSelector: 'a.product-item-link',
      imageSelector: '.cs-product-tile__image img, .product-image-photo',
      stockKeywords: ['€'],
      outOfStockKeywords: ['nicht verfügbar', 'ausverkauft', 'sold out'],
      currency: 'EUR',
      currencySymbol: '€'
    };
  }

  /**
   * Extract image URL from Yoshien product element
   * Yoshien uses Magento structure with lazy loading and specific image paths
   */
  extractImageUrl(productElement, config) {
    const selectors = [
      '.cs-product-tile__image img',
      '.product-image-photo',
      'img[src*="media/catalog/product"]',
      'a.product-item-link img',
      '.product-item-photo img'
    ];
    
    for (const selector of selectors) {
      const img = productElement.find(selector).first();
      if (img.length) {
        let imageUrl = null;
        
        // Handle lazy loading - prioritize data-src over src for Yoshien
        imageUrl = img.attr('data-src') || img.attr('data-original') || img.attr('src');
        
        // Handle additional lazy loading attributes specific to Magento
        if (!imageUrl || imageUrl.includes('data:image/gif')) {
          imageUrl = img.attr('data-lazy') || 
                    img.attr('data-srcset') || 
                    img.attr('data-image-src') ||
                    img.attr('data-main-image');
          
          if (imageUrl && imageUrl.includes(',')) {
            // Extract first URL from srcset
            imageUrl = imageUrl.split(',')[0].trim().split(' ')[0];
          }
        }

        // Skip base64 placeholder images completely
        if (imageUrl && imageUrl.includes('data:image/gif')) {
          this.logger.warn('Skipping base64 placeholder image', { 
            selector,
            placeholder: imageUrl.substring(0, 50) + '...'
          });
          continue;
        }

        if (imageUrl && imageUrl.trim() !== '') {
          // Handle relative URLs
          if (imageUrl.startsWith('//')) {
            imageUrl = 'https:' + imageUrl;
          } else if (imageUrl.startsWith('/')) {
            imageUrl = this.baseUrl + imageUrl;
          } else if (!imageUrl.startsWith('http')) {
            imageUrl = this.baseUrl + '/' + imageUrl;
          }
          
          // Clean up Magento image URLs
          if (imageUrl.includes('/cache/')) {
            // Remove cache path and parameters for cleaner URLs
            imageUrl = imageUrl.replace(/\/cache\/[^\/]+/, '');
          }
          
          // Remove query parameters and resize parameters
          imageUrl = imageUrl.split('?')[0];
          
          // Validate URL format
          try {
            new URL(imageUrl);
            this.logger.info('Extracted Yoshien image URL', { 
              imageUrl, 
              selector,
              originalSrc: img.attr('src'),
              originalDataSrc: img.attr('data-src')
            });
            return imageUrl;
          } catch (e) {
            this.logger.warn('Invalid Yoshien image URL format', { 
              imageUrl, 
              selector,
              error: e.message
            });
            continue;
          }
        }
      }
    }

    this.logger.warn('No valid image URL found for Yoshien product');
    return null;
  }

  /**
   * Clean price text specific to Yoshien format
   */
  cleanPrice(priceText) {
    if (!priceText) return null;
    
    const cleaned = priceText.replace(/\s+/g, ' ').trim();
    
    // Look for EUR prices
    const eurMatch = cleaned.match(/€\s*(\d+[.,]\d*)/);
    if (eurMatch) {
      const price = eurMatch[1].replace(',', '.');
      return `€${price}`;
    }
    
    // Fallback pattern for prices without symbol
    const fallbackMatch = cleaned.match(/(\d+[.,]\d+)/);
    if (fallbackMatch) {
      const price = fallbackMatch[1].replace(',', '.');
      return `€${price}`;
    }
    
    return null;
  }

  /**
   * Extract product name from Yoshien elements
   */
  extractProductName(productElement) {
    const selectors = [
      'a.product-item-link',
      '.product-item-name a',
      '.product-name',
      'h2 a',
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
   * Check stock status for Yoshien products
   * In Magento/Yoshien, if price is visible, product is usually in stock
   */
  checkStockStatus(productElement) {
    // Check for explicit out of stock indicators
    const outOfStockSelectors = [
      '.stock.unavailable',
      '.out-of-stock',
      ':contains("nicht verfügbar")',
      ':contains("ausverkauft")',
      ':contains("sold out")'
    ];
    
    for (const selector of outOfStockSelectors) {
      if (productElement.find(selector).length > 0) {
        return false;
      }
    }
    
    // If price is present, assume in stock (Magento default behavior)
    const priceElement = productElement.find('.price');
    if (priceElement.length > 0 && priceElement.text().trim()) {
      return true;
    }
    
    // Default to in stock if no clear indicators
    return true;
  }

  /**
   * Generate product ID for Yoshien products
   */
  generateProductId(url, name) {
    const urlPath = url.replace(this.baseUrl, '').replace(/^\//, '');
    const cleanName = name ? name.toLowerCase().replace(/[^a-z0-9]/g, '') : '';
    
    if (urlPath.includes('/')) {
      const pathParts = urlPath.split('/');
      const lastPart = pathParts[pathParts.length - 1];
      return `yoshien_${lastPart}_${cleanName}`.substring(0, 100);
    }
    
    return `yoshien_${cleanName}`.substring(0, 100);
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
      'culinary grade'
    ];
    
    return matchaKeywords.some(keyword => searchText.includes(keyword));
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
   * Download and compress image, then upload to Firebase Storage
   */
  async downloadAndStoreImage(imageUrl, productId, siteKey) {
    try {
      if (!imageUrl || imageUrl.includes('data:') || imageUrl.includes('placeholder')) {
        return null;
      }

      const { getStorage } = require('firebase-admin/storage');
      const axios = require('axios');
      const sharp = require('sharp');
      
      // Initialize storage if not already done
      if (!this.storage) {
        this.storage = getStorage();
      }

      // Check if image already exists in Firebase Storage
      const fileName = `product-images/${siteKey}/${productId}.jpg`;
      const file = this.storage.bucket().file(fileName);
      
      try {
        const [exists] = await file.exists();
        if (exists) {
          // Image already exists, return the existing URL
          const bucketName = this.storage.bucket().name;
          // Handle bucket names that already include .firebasestorage.app
          const cleanBucketName = bucketName.replace('.firebasestorage.app', '');
          const publicUrl = `https://storage.googleapis.com/${cleanBucketName}.firebasestorage.app/${fileName}`;
          this.logger.info('Using existing image from storage', { 
            productId, 
            siteKey, 
            publicUrl 
          });
          return publicUrl;
        }
      } catch (existsError) {
        // If checking existence fails, proceed to download
        this.logger.warn('Failed to check if image exists, proceeding to download', { 
          productId, 
          siteKey, 
          error: existsError.message 
        });
      }

      this.logger.info('Downloading image', { 
        productId, 
        siteKey, 
        imageUrl 
      });

      // Download image with improved error handling
      const response = await axios({
        method: 'GET',
        url: imageUrl,
        responseType: 'arraybuffer',
        timeout: 20000, // Increased timeout
        maxRedirects: 5,
        headers: {
          'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
          'Accept': 'image/*',
        }
      });

      // Validate response
      if (!response.data || response.data.length === 0) {
        this.logger.warn('Empty image response', { productId, siteKey, imageUrl });
        return null;
      }

      // Check if response is actually an image
      const contentType = response.headers['content-type'];
      if (contentType && !contentType.startsWith('image/')) {
        this.logger.warn('Response is not an image', { 
          productId, 
          siteKey, 
          imageUrl, 
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
          imageUrl,
          error: sharpError.message
        });
        return null;
      }

      // Upload to Firebase Storage
      await file.save(compressedImageBuffer, {
        metadata: {
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=86400', // 1 day cache
        }
      });

      // Make file publicly accessible
      await file.makePublic();

      // Return public URL
      const bucketName = this.storage.bucket().name;
      // Handle bucket names that already include .firebasestorage.app
      const cleanBucketName = bucketName.replace('.firebasestorage.app', '');
      const publicUrl = `https://storage.googleapis.com/${cleanBucketName}.firebasestorage.app/${fileName}`;
      
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
}

module.exports = YoshienSpecializedCrawler;
