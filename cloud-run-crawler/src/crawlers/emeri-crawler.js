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
    
    // Initialize Firebase Storage
    const { getStorage } = require('firebase-admin/storage');
    this.storage = getStorage();
    
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
      // Use default config if none provided
      const crawlerConfig = config || this.getConfig();
      const response = await axios.get(targetUrl, this.requestConfig);
      const $ = cheerio.load(response.data);

      const products = [];
      const productElements = $(crawlerConfig.productSelector || '.product-card');
      
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
          const linkElement = productElement.find(crawlerConfig.linkSelector || 'a');
          if (linkElement.length) {
            const href = linkElement.attr('href');
            if (href) {
              productUrl = href.startsWith('http') ? href : this.baseUrl + href;
            }
          }

          // Extract price
          const priceElement = productElement.find(crawlerConfig.priceSelector || '.price');
          const rawPrice = priceElement.text().trim();
          const price = this.cleanPrice(rawPrice);

          // Check stock status
          const isInStock = this.checkStockStatus(productElement);

          // Generate product ID
          const productId = this.generateProductId(productUrl || targetUrl, name);

          // Extract and process image URL
          let imageUrl = null;
          
          // First, try to use existing Firebase Storage image
          const fileName = `product-images/enjoyemeri/${productId}.jpg`;
          const file = this.storage.bucket().file(fileName);
          
          try {
            const [exists] = await file.exists();
            if (exists) {
              // Image already exists, use the Firebase Storage URL
              const bucketName = this.storage.bucket().name;
              const cleanBucketName = bucketName.replace('.firebasestorage.app', '');
              imageUrl = `https://storage.googleapis.com/${cleanBucketName}.firebasestorage.app/${fileName}`;
              this.logger.info('Using existing image from Firebase Storage', { 
                productId, 
                imageUrl 
              });
            } else {
              // Image doesn't exist, try to download from source
              const rawImageUrl = this.extractImageUrl(productElement, crawlerConfig);
              if (rawImageUrl) {
                imageUrl = await this.downloadAndStoreImage(rawImageUrl, productId);
              }
            }
          } catch (existsError) {
            this.logger.warn('Failed to check Firebase Storage, trying source download', { 
              productId, 
              error: existsError.message 
            });
            // Fallback to download from source
            const rawImageUrl = this.extractImageUrl(productElement, crawlerConfig);
            if (rawImageUrl) {
              imageUrl = await this.downloadAndStoreImage(rawImageUrl, productId);
            }
          }

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
      imageSelector: 'img.product-media__image, .product-card__image img',
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
      'img.product-media__image',  // Images with product-media__image class directly
      '.product-media__image img', // Original selector as fallback
      '.product-card__image img',
      '.product-image img',
      '.card__media img',
      'img[src*="cdn/shop/files/"]', // Emeri uses cdn/shop/files instead of products
      'img[alt*="Matcha"], img[alt*="Bowl"], img[alt*="Whisk"]' // Alt text based matching
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
          // Handle protocol-relative URLs (common in Emeri)
          if (imageUrl.startsWith('//')) {
            imageUrl = 'https:' + imageUrl;
          } else if (imageUrl.startsWith('/')) {
            imageUrl = this.baseUrl + imageUrl;
          }

          // Validate URL
          if (imageUrl.includes('cdn.shop') || imageUrl.includes('enjoyemeri')) {
            // Remove width parameter for higher quality
            const cleanUrl = imageUrl.split('?')[0] + '?width=800'; // Set consistent width
            
            this.logger.info('Found Emeri product image', {
              selector,
              imageUrl: cleanUrl,
              alt: img.attr('alt')
            });
            
            return cleanUrl;
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

  /**
   * Download and store image to Firebase Storage
   */
  async downloadAndStoreImage(imageUrl, productId) {
    const axios = require('axios');
    const sharp = require('sharp');
    
    try {
      if (!imageUrl || imageUrl.includes('data:') || imageUrl.includes('placeholder')) {
        return null;
      }

      // Check if image already exists in Firebase Storage
      const fileName = `product-images/enjoyemeri/${productId}.jpg`;
      const file = this.storage.bucket().file(fileName);
      
      try {
        const [exists] = await file.exists();
        if (exists) {
          // Image already exists, return the existing URL
          const bucketName = this.storage.bucket().name;
          const cleanBucketName = bucketName.replace('.firebasestorage.app', '');
          const publicUrl = `https://storage.googleapis.com/${cleanBucketName}.firebasestorage.app/${fileName}`;
          this.logger.info('Using existing image from storage', { 
            productId, 
            siteKey: 'enjoyemeri', 
            publicUrl 
          });
          return publicUrl;
        }
      } catch (existsError) {
        this.logger.warn('Failed to check if image exists, proceeding to download', { 
          productId, 
          siteKey: 'enjoyemeri', 
          error: existsError.message 
        });
      }

      // Make URL absolute if relative
      let absoluteUrl = imageUrl;
      if (imageUrl.startsWith('//')) {
        absoluteUrl = 'https:' + imageUrl;
      } else if (imageUrl.startsWith('/')) {
        absoluteUrl = this.baseUrl + imageUrl;
      }

      // Validate URL format before attempting download
      try {
        new URL(absoluteUrl);
      } catch (urlError) {
        this.logger.warn('Invalid image URL format', { productId, siteKey: 'enjoyemeri', imageUrl: absoluteUrl });
        // Try to return existing image URL if validation fails
        return await this.tryExistingImageUrl(productId);
      }

      this.logger.info('Downloading image', { 
        productId, 
        siteKey: 'enjoyemeri', 
        imageUrl: absoluteUrl 
      });

      // Download image with improved error handling
      const response = await axios({
        method: 'GET',
        url: absoluteUrl,
        responseType: 'arraybuffer',
        timeout: 20000,
        maxRedirects: 5,
        headers: {
          'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
          'Accept': 'image/*',
        }
      });

      // Validate response
      if (!response.data || response.data.length === 0) {
        this.logger.warn('Empty image response', { productId, siteKey: 'enjoyemeri', imageUrl: absoluteUrl });
        return await this.tryExistingImageUrl(productId);
      }

      // Check if response is actually an image
      const contentType = response.headers['content-type'];
      if (contentType && !contentType.startsWith('image/')) {
        this.logger.warn('Response is not an image', { 
          productId, 
          siteKey: 'enjoyemeri', 
          imageUrl: absoluteUrl, 
          contentType 
        });
        return await this.tryExistingImageUrl(productId);
      }

      // Compress image using Sharp
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
          siteKey: 'enjoyemeri',
          imageUrl: absoluteUrl,
          error: sharpError.message
        });
        return await this.tryExistingImageUrl(productId);
      }

      // Upload to Firebase Storage
      await file.save(compressedImageBuffer, {
        metadata: {
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=86400',
        }
      });

      // Make file publicly accessible
      await file.makePublic();

      // Return public URL
      const bucketName = this.storage.bucket().name;
      const cleanBucketName = bucketName.replace('.firebasestorage.app', '');
      const publicUrl = `https://storage.googleapis.com/${cleanBucketName}.firebasestorage.app/${fileName}`;
      
      this.logger.info('Image uploaded successfully', { 
        productId, 
        siteKey: 'enjoyemeri',
        publicUrl,
        originalSize: response.data.length,
        compressedSize: compressedImageBuffer.length
      });

      return publicUrl;

    } catch (error) {
      this.logger.error('Failed to download and store image', {
        productId,
        siteKey: 'enjoyemeri',
        imageUrl,
        error: error.message
      });
      // Try to return existing image URL if download fails
      return await this.tryExistingImageUrl(productId);
    }
  }

  /**
   * Try to construct existing image URL if image exists in storage
   */
  async tryExistingImageUrl(productId) {
    try {
      const fileName = `product-images/enjoyemeri/${productId}.jpg`;
      const file = this.storage.bucket().file(fileName);
      const [exists] = await file.exists();
      
      if (exists) {
        const bucketName = this.storage.bucket().name;
        const cleanBucketName = bucketName.replace('.firebasestorage.app', '');
        const publicUrl = `https://storage.googleapis.com/${cleanBucketName}.firebasestorage.app/${fileName}`;
        this.logger.info('Fallback: Using existing image from storage', { 
          productId, 
          publicUrl 
        });
        return publicUrl;
      }
    } catch (error) {
      this.logger.warn('Failed to check for existing image fallback', {
        productId,
        error: error.message
      });
    }
    return null;
  }
}

module.exports = EmeriSpecializedCrawler;
