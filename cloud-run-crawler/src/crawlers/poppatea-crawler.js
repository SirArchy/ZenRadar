const axios = require('axios');
const cheerio = require('cheerio');

/**
 * Poppatea specific crawler with enhanced variant extraction
 * Handles complex variant structures and Swedish language
 */
class PoppateaSpecializedCrawler {
  constructor(logger) {
    this.logger = logger;
    this.baseUrl = 'https://poppatea.com';
    
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
    const targetUrl = categoryUrl || 'https://poppatea.com/de-de/collections/all-teas';
    
    try {
      const response = await axios.get(targetUrl, this.requestConfig);
      const $ = cheerio.load(response.data);

      const products = [];
      
      // Poppatea uses paired cards - we need cards that contain product titles
      const productCards = $('.card').filter((i, el) => {
        return $(el).find('.card__title').length > 0;
      });
      
      this.logger.info('Found Poppatea product cards with titles', {
        count: productCards.length
      });

      // Extract product data from title cards and construct product URLs
      const seenProducts = new Set();
      
      for (let i = 0; i < productCards.length; i++) {
        const productCard = $(productCards[i]);
        
        try {
          // Extract product name from card title
          const titleElement = productCard.find('.card__title').first();
          const baseName = titleElement.text().trim();
          
          if (!baseName || baseName.length < 2) {
            this.logger.warn('No valid product name found in card', { index: i });
            continue;
          }
          
          // Skip duplicates
          if (seenProducts.has(baseName)) {
            continue;
          }
          seenProducts.add(baseName);
          
          // Extract price from the card
          const priceElement = productCard.find('.price').first();
          const priceText = priceElement.text().trim();
          
          // Construct product URL from the product name
          // Poppatea uses German URLs like: /de-de/collections/all-teas/products/matcha-tea-ceremonial
          const urlSlug = this.createUrlSlug(baseName);
          const productUrl = `https://poppatea.com/de-de/collections/all-teas/products/${urlSlug}`;
          
          // Find matching image card (usually preceding the title card)
          let imageUrl = null;
          const imageCards = $('.card').filter((idx, el) => {
            return $(el).find('img').length > 0 && !$(el).find('.card__title').length;
          });
          
          // Try to match image with product based on position
          if (imageCards.length > i) {
            const imgElement = $(imageCards[i]).find('img').first();
            if (imgElement.length) {
              const src = imgElement.attr('src') || imgElement.attr('data-src');
              if (src) {
                imageUrl = src.startsWith('//') ? 'https:' + src : 
                          src.startsWith('/') ? 'https://poppatea.com' + src : src;
              }
            }
          }

          // Extract variants from the individual product page
          const variants = await this.extractVariantsFromProductPage(productUrl, baseName);
          
          if (variants.length > 0) {
            // Update image URL for variants if we found one
            if (imageUrl) {
              variants.forEach(variant => {
                if (!variant.imageUrl) {
                  variant.imageUrl = imageUrl;
                }
              });
            }
            
            products.push(...variants);
            this.logger.info('Added Poppatea variants', {
              baseName,
              variantCount: variants.length,
              url: productUrl
            });
          } else {
            // Create single product if no variants found
            const singleProduct = this.createSingleProductFromCard(baseName, productUrl, priceText, imageUrl);
            if (singleProduct) {
              products.push(singleProduct);
              this.logger.info('Added single Poppatea product', {
                name: baseName,
                url: productUrl
              });
            }
          }

        } catch (error) {
          this.logger.warn('Failed to process Poppatea product card', {
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
      this.logger.error('Poppatea category page crawl failed', {
        url: targetUrl,
        error: error.message
      });
      throw error;
    }
  }

  async extractVariantsFromProductPage(productUrl, baseName) {
    try {
      const response = await axios.get(productUrl, this.requestConfig);
      const $ = cheerio.load(response.data);
      const variants = [];

      // Extract main product image from the individual product page
      let mainImageUrl = null;
      const imageSelectors = [
        '.product__media img',
        '.product-single__photos img',
        '.product__photo img',
        'img[src*="cdn/shop"][alt*="' + baseName.toLowerCase() + '"]',
        'img[src*="cdn/shop"]'
      ];
      
      for (const selector of imageSelectors) {
        const img = $(selector).first();
        if (img.length) {
          const src = img.attr('src') || img.attr('data-src') || img.attr('data-original');
          if (src && src.includes('cdn/shop') && !src.includes('icon') && !src.includes('logo')) {
            mainImageUrl = src.startsWith('http') ? src : 
                          src.startsWith('//') ? 'https:' + src : 
                          this.baseUrl + src;
            break;
          }
        }
      }

      // If no specific image found, try to find the primary product image
      if (!mainImageUrl) {
        const allImages = $('img[src*="cdn/shop"]');
        allImages.each((_, img) => {
          const src = $(img).attr('src');
          const alt = $(img).attr('alt') || '';
          
          if (src && !src.includes('icon') && !src.includes('logo') && 
              (alt.toLowerCase().includes(baseName.toLowerCase()) || 
               src.includes('width=500') || src.includes('width=600'))) {
            mainImageUrl = src.startsWith('http') ? src : 
                          src.startsWith('//') ? 'https:' + src : 
                          this.baseUrl + src;
            return false; // Break out of each loop
          }
        });
      }

      // Method 1: Look for Shopify product JSON (most reliable)
      let foundVariants = false;
      const scriptTags = $('script');
      
      scriptTags.each((_, script) => {
        const scriptContent = $(script).html();
        if (scriptContent && scriptContent.includes('"variants"') && scriptContent.includes('"product"')) {
          try {
            // Look for product JSON pattern in Shopify
            const productMatches = scriptContent.match(/"product"\s*:\s*\{[^}]+?"variants"\s*:\s*\[[^\]]*\]/);
            if (productMatches) {
              // Extract just the variants array
              const variantMatches = scriptContent.match(/"variants"\s*:\s*\[([^\]]*)\]/);
              if (variantMatches) {
                const variantArray = JSON.parse('[' + variantMatches[1] + ']');
                
                this.logger.info('Found variants in Shopify JSON', { 
                  count: variantArray.length,
                  baseName 
                });

                // Get variant-specific images
                const variantImages = this.extractVariantImages($, baseName);

                variantArray.forEach((variant, index) => {
                  // Try to match variant with appropriate image
                  let variantImageUrl = mainImageUrl; // Default to main image
                  
                  if (variantImages.length > 0) {
                    variantImageUrl = this.matchVariantImage(variant, variantImages, baseName) || mainImageUrl;
                  }
                  
                  const variantProduct = this.createVariantProduct(
                    variant, 
                    baseName, 
                    productUrl, 
                    variantImageUrl
                  );
                  if (variantProduct) {
                    variants.push(variantProduct);
                  }
                });
                foundVariants = true;
                return false; // Break out of each loop
              }
            }
          } catch (e) {
            this.logger.warn('Failed to parse Shopify product JSON', {
              error: e.message,
              baseName
            });
          }
        }
      });

      // Method 2: Look for variant form elements if JSON method failed
      if (!foundVariants) {
        const variantSelectors = $('select[name="id"] option[value], .product-form__option select option');
        
        if (variantSelectors.length > 0) {
          this.logger.info('Found variants in form elements', { 
            count: variantSelectors.length,
            baseName 
          });

          variantSelectors.each((_, option) => {
            const $option = $(option);
            const variantId = $option.attr('value');
            const variantText = $option.text().trim();
            
            if (variantId && variantText && variantId !== '' && !$option.attr('disabled')) {
              const variantProduct = this.createVariantFromText(
                variantText, 
                baseName, 
                productUrl, 
                mainImageUrl,
                variantId
              );
              if (variantProduct) {
                variants.push(variantProduct);
              }
            }
          });
          foundVariants = true;
        }
      }

      // Method 3: Look for variant buttons/labels if other methods failed
      if (!foundVariants) {
        const variantButtons = $('.variant-option, .size-variant, input[name="Size"]');
        
        if (variantButtons.length > 0) {
          this.logger.info('Found variants in buttons/labels', { 
            count: variantButtons.length,
            baseName 
          });

          variantButtons.each((_, button) => {
            const $button = $(button);
            let variantText = $button.text().trim() || $button.attr('value') || $button.attr('data-value');
            
            if (variantText) {
              const variantProduct = this.createVariantFromText(
                variantText, 
                baseName, 
                productUrl, 
                mainImageUrl
              );
              if (variantProduct) {
                variants.push(variantProduct);
              }
            }
          });
          foundVariants = true;
        }
      }

      // If no variants found, create a single product
      if (!foundVariants || variants.length === 0) {
        this.logger.info('No variants found, creating single product', { baseName });
        
        const singleProduct = this.createSingleProduct(baseName, productUrl, mainImageUrl, $);
        if (singleProduct) {
          variants.push(singleProduct);
        }
      }

      // Filter and validate variants
      const validVariants = variants.filter(v => 
        v && v.name && v.name.trim().length > 0 && v.priceValue > 0
      );

      this.logger.info('Processed Poppatea variants', {
        productUrl,
        baseName,
        totalExtracted: variants.length,
        validVariants: validVariants.length,
        variantNames: validVariants.map(v => v.name).slice(0, 3)
      });

      return validVariants;

    } catch (error) {
      this.logger.error('Failed to extract Poppatea variants', {
        productUrl,
        baseName,
        error: error.message
      });
      return [];
    }
  }

  createVariantProduct(variant, baseName, productUrl, mainImageUrl) {
    try {
      // Extract variant information - Poppatea uses title field for variant names
      const variantName = variant.title || variant.name || '';
      const price = variant.price ? (variant.price / 100) : 0; // Shopify stores price in cents
      const available = variant.available !== false && variant.available !== undefined;

      // Create full product name - variant title already includes base name
      const fullName = variantName || baseName;

      // Price is already in EUR for Poppatea
      const eurPrice = price;

      const productId = this.generateProductId(productUrl, fullName);
      const currentTimestamp = new Date();

      return {
        id: productId,
        name: fullName,
        normalizedName: this.normalizeName(fullName),
        site: 'poppatea',
        siteName: 'Poppatea',
        price: `€${eurPrice.toFixed(2)}`,
        originalPrice: `€${eurPrice.toFixed(2)}`,
        priceValue: eurPrice,
        currency: 'EUR',
        url: productUrl,
        imageUrl: mainImageUrl,
        isInStock: available,
        category: this.detectCategory(baseName),
        lastChecked: currentTimestamp,
        lastUpdated: currentTimestamp,
        lastPriceHistoryUpdate: currentTimestamp,
        firstSeen: currentTimestamp,
        isDiscontinued: false,
        missedScans: 0,
        crawlSource: 'cloud-run',
        variantId: variant.id
      };
    } catch (error) {
      this.logger.warn('Failed to create variant product', {
        variant,
        baseName,
        error: error.message
      });
      return null;
    }
  }

  createVariantFromText(variantText, baseName, productUrl, mainImageUrl, variantId = null) {
    try {
      // Parse the variant text to extract size and price
      const parsed = this.parseVariantText(variantText, baseName);
      if (!parsed) return null;

      const productId = this.generateProductId(productUrl, parsed.name);
      const currentTimestamp = new Date();

      return {
        id: productId,
        name: parsed.name,
        normalizedName: this.normalizeName(parsed.name),
        site: 'poppatea',
        siteName: 'Poppatea',
        price: parsed.price,
        originalPrice: parsed.originalPrice,
        priceValue: parsed.priceValue,
        currency: parsed.currency,
        url: productUrl,
        imageUrl: mainImageUrl,
        isInStock: true, // Assume in stock if variant is selectable
        category: this.detectCategory(baseName),
        lastChecked: currentTimestamp,
        lastUpdated: currentTimestamp,
        lastPriceHistoryUpdate: currentTimestamp,
        firstSeen: currentTimestamp,
        isDiscontinued: false,
        missedScans: 0,
        crawlSource: 'cloud-run',
        variantId: variantId
      };
    } catch (error) {
      this.logger.warn('Failed to create variant from text', {
        variantText,
        baseName,
        error: error.message
      });
      return null;
    }
  }

  createSingleProduct(baseName, productUrl, mainImageUrl, $) {
    try {
      // Extract price from the page
      let price = '';
      const priceSelectors = ['.price', '.money', '.product-price', '.price__current'];
      
      for (const selector of priceSelectors) {
        const priceEl = $(selector).first();
        if (priceEl.length) {
          price = priceEl.text().trim();
          if (price) break;
        }
      }

      // Clean and convert price
      const cleanedPrice = this.cleanPoppateaPrice(price);
      if (!cleanedPrice) return null;

      const productId = this.generateProductId(productUrl, baseName);

      return {
        id: productId,
        name: baseName,
        normalizedName: this.normalizeName(baseName),
        site: 'poppatea',
        siteName: 'Poppatea',
        price: cleanedPrice,
        originalPrice: price,
        priceValue: this.extractPriceValue(cleanedPrice),
        currency: 'EUR',
        url: productUrl,
        imageUrl: mainImageUrl,
        isInStock: !$('.sold-out, .unavailable').length && 
                   !$('body').text().toLowerCase().includes('ausverkauft'),
        category: this.detectCategory(baseName),
        lastChecked: new Date(),
        lastUpdated: new Date(),
        firstSeen: new Date(),
        isDiscontinued: false,
        missedScans: 0,
        crawlSource: 'cloud-run'
      };
    } catch (error) {
      this.logger.warn('Failed to create single product', {
        baseName,
        error: error.message
      });
      return null;
    }
  }

  parseVariantText(text, baseName) {
    // Patterns for Swedish/German Poppatea variants
    const patterns = [
      // "50g Dose (50 Portionen)" -> size and description
      /(\d+g)\s*(Dose|Nachfüllbeutel)\s*\((\d+)\s*Portionen\)/i,
      // "2 x 50 g Nachfüllbeutel (100 Portionen)"
      /(\d+)\s*x\s*(\d+g)\s*(Nachfüllbeutel)\s*\((\d+)\s*Portionen\)/i,
      // "50g - €12.50" or "50g / €25.00"
      /(\d+g)\s*[-\/]\s*€(\d+[,.]?\d*)/,
      // "50g - 160 kr" (Swedish Krona)
      /(\d+g)\s*[-\/]\s*(\d+)\s*kr/i,
      // "50g (€12.50)" or "50g (160 kr)"
      /(\d+g)\s*\(\s*€?(\d+[,.]?\d*)\s*kr?\)/i,
    ];

    for (const pattern of patterns) {
      const match = text.match(pattern);
      if (match) {
        if (match.length >= 4 && match[3]) {
          // Handle "2 x 50g Nachfüllbeutel" pattern
          const quantity = match[1];
          const size = match[2];
          const type = match[3];
          const portions = match[4];
          
          return {
            name: `${baseName} (${quantity} x ${size} ${type})`,
            normalizedName: this.normalizeName(`${baseName} ${quantity} ${size} ${type}`),
            price: '', // Price will be extracted separately
            originalPrice: '',
            priceValue: 0,
            currency: 'EUR'
          };
        } else if (match.length >= 3) {
          // Handle "50g Dose" or price patterns
          const size = match[1];
          const typeOrPrice = match[2];
          
          if (typeOrPrice && (typeOrPrice.includes('Dose') || typeOrPrice.includes('Nachfüllbeutel'))) {
            const portions = match[3] || '';
            const fullType = portions ? `${typeOrPrice} (${portions} Portionen)` : typeOrPrice;
            
            return {
              name: `${baseName} (${size} ${fullType})`,
              normalizedName: this.normalizeName(`${baseName} ${size} ${fullType}`),
              price: '',
              originalPrice: '',
              priceValue: 0,
              currency: 'EUR'
            };
          } else {
            // This is a price pattern
            let price = parseFloat(typeOrPrice.replace(',', '.'));
            let currency = 'EUR';
            
            // Check if this is Swedish Krona
            if (text.toLowerCase().includes('kr')) {
              price = this.convertSEKToEUR(price);
            }
            
            return {
              name: `${baseName} (${size})`,
              normalizedName: this.normalizeName(`${baseName} ${size}`),
              price: `€${price.toFixed(2)}`,
              originalPrice: text.includes('kr') ? `${typeOrPrice} kr` : `€${typeOrPrice}`,
              priceValue: price,
              currency: currency
            };
          }
        }
      }
    }

    // If no pattern matches but text seems like a meaningful variant
    if (text.length > 2 && text.length < 100) {
      return {
        name: `${baseName} (${text})`,
        normalizedName: this.normalizeName(`${baseName} ${text}`),
        price: '',
        originalPrice: '',
        priceValue: 0,
        currency: 'EUR'
      };
    }

    return null;
  }

  convertSEKToEUR(sekAmount) {
    // 1 SEK = 0.085 EUR (approximate rate)
    return sekAmount * 0.085;
  }

  cleanPoppateaPrice(priceStr) {
    if (!priceStr) return '';

    let cleaned = priceStr.trim();
    
    // Remove German price text
    cleaned = cleaned.replace(/Normaler Preis|Verkaufspreis|Ab|Stückpreis|pro|per/gi, '');
    cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();
    
    // Handle "Ab €15,00" format (German)
    const germanPriceMatch = cleaned.match(/€\s*(\d+),(\d{2})/);
    if (germanPriceMatch) {
      const euros = germanPriceMatch[1];
      const cents = germanPriceMatch[2];
      return `€${euros}.${cents}`;
    }
    
    // Handle "€15.00" format
    const eurMatch = cleaned.match(/€\s*(\d+)\.(\d{2})/);
    if (eurMatch) {
      return `€${eurMatch[1]}.${eurMatch[2]}`;
    }
    
    // Handle "15,00" format (German decimal)
    const decimalMatch = cleaned.match(/(\d+),(\d{2})/);
    if (decimalMatch) {
      return `€${decimalMatch[1]}.${decimalMatch[2]}`;
    }
    
    // Handle Swedish Krona format (XXX kr) - legacy support
    const krMatch = cleaned.match(/(\d+)\s*kr/i);
    if (krMatch) {
      const sekValue = parseFloat(krMatch[1]);
      const euroValue = this.convertSEKToEUR(sekValue);
      return `€${euroValue.toFixed(2)}`;
    }
    
    // Handle prices without decimals
    const simpleMatch = cleaned.match(/€?\s*(\d+)\s*€?/);
    if (simpleMatch) {
      return `€${simpleMatch[1]}.00`;
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

  generateProductId(url, name) {
    const urlPart = url.split('/').pop().split('?')[0] || '';
    const namePart = name.toLowerCase().replace(/[^a-z0-9]/g, '').substring(0, 20);
    
    return `poppatea_${urlPart}_${namePart}`.replace(/[^a-z0-9_]/g, '');
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

    if (lower.includes('whisk') || lower.includes('chasen') || lower.includes('bowl')) {
      return 'Accessories';
    }

    if (lower.includes('set') || lower.includes('kit')) {
      return 'Tea Sets';
    }

    if (lower.includes('matcha')) {
      if (lower.includes('ceremonial')) return 'Ceremonial Matcha';
      if (lower.includes('premium')) return 'Premium Matcha';
      if (lower.includes('cooking') || lower.includes('culinary')) return 'Culinary Matcha';
      return 'Matcha';
    }

    return 'Matcha';
  }

  extractVariantImages($, baseName) {
    const images = [];
    
    // Get all product images from the page
    const productImages = $('img[src*="cdn/shop"]');
    
    productImages.each((_, img) => {
      const src = $(img).attr('src');
      const alt = $(img).attr('alt') || '';
      
      if (src && !src.includes('icon') && !src.includes('logo') && !src.includes('Main_Color')) {
        // Normalize URL
        const imageUrl = src.startsWith('http') ? src : 
                        src.startsWith('//') ? 'https:' + src : 
                        this.baseUrl + src;
        
        // Categorize images by variant type
        let variantType = 'default';
        const lowerAlt = alt.toLowerCase();
        const lowerSrc = src.toLowerCase();
        
        if (lowerAlt.includes('pouch') || lowerSrc.includes('pouch')) {
          variantType = 'pouch';
        } else if (lowerAlt.includes('2 x') || lowerSrc.includes('2_x')) {
          variantType = '2pack';
        } else if (lowerAlt.includes('tin') || lowerSrc.includes('tin') || lowerAlt.includes('dose')) {
          variantType = 'tin';
        }
        
        images.push({
          url: imageUrl,
          alt: alt,
          variantType: variantType,
          priority: this.getImagePriority(src, alt)
        });
      }
    });
    
    // Sort by priority (higher is better)
    return images.sort((a, b) => b.priority - a.priority);
  }

  getImagePriority(src, alt) {
    let priority = 0;
    
    // Prefer larger images
    if (src.includes('width=600')) priority += 3;
    else if (src.includes('width=500')) priority += 2;
    else if (src.includes('width=300')) priority += 1;
    
    // Prefer images with descriptive alt text
    if (alt && alt.length > 10) priority += 2;
    
    // Prefer main product images
    if (alt.toLowerCase().includes('tea') || alt.toLowerCase().includes('matcha') || alt.toLowerCase().includes('hojicha')) {
      priority += 1;
    }
    
    return priority;
  }

  matchVariantImage(variant, images, baseName) {
    const variantTitle = variant.title || '';
    const lowerTitle = variantTitle.toLowerCase();
    
    // Try to match variant type with appropriate image
    if (lowerTitle.includes('dose') || lowerTitle.includes('tin')) {
      const tinImage = images.find(img => img.variantType === 'tin');
      if (tinImage) return tinImage.url;
    }
    
    if (lowerTitle.includes('nachfüllbeutel') || lowerTitle.includes('pouch')) {
      if (lowerTitle.includes('2 x')) {
        const twoPackImage = images.find(img => img.variantType === '2pack');
        if (twoPackImage) return twoPackImage.url;
      } else {
        const pouchImage = images.find(img => img.variantType === 'pouch');
        if (pouchImage) return pouchImage.url;
      }
    }
    
    // Fallback to highest priority image that matches the base product
    const productImages = images.filter(img => 
      img.alt.toLowerCase().includes(baseName.toLowerCase()) ||
      img.variantType === 'default'
    );
    
    return productImages.length > 0 ? productImages[0].url : null;
  }

  createUrlSlug(productName) {
    // Convert German product names to URL slugs
    return productName
      .toLowerCase()
      .replace(/matcha tee/g, 'matcha-tea')
      .replace(/zeremoniell/g, 'ceremonial')
      .replace(/hojicha-teepulver/g, 'hojicha-tea-powder')
      .replace(/mit chai/g, 'with-chai')
      .replace(/\s+/g, '-')
      .replace(/[^a-z0-9-]/g, '')
      .replace(/-+/g, '-')
      .replace(/^-|-$/g, '');
  }

  createSingleProductFromCard(baseName, productUrl, priceText, imageUrl) {
    try {
      // Clean and convert price
      const cleanedPrice = this.cleanPoppateaPrice(priceText);
      if (!cleanedPrice) {
        this.logger.warn('No valid price found for single product', { baseName, priceText });
        return null;
      }

      const productId = this.generateProductId(productUrl, baseName);

      return {
        id: productId,
        name: baseName,
        normalizedName: this.normalizeName(baseName),
        site: 'poppatea',
        siteName: 'Poppatea',
        price: cleanedPrice,
        originalPrice: priceText,
        priceValue: this.extractPriceValue(cleanedPrice),
        currency: 'EUR',
        url: productUrl,
        imageUrl: imageUrl,
        isInStock: true, // Assume in stock if listed
        category: this.detectCategory(baseName),
        lastChecked: new Date(),
        lastUpdated: new Date(),
        firstSeen: new Date(),
        isDiscontinued: false,
        missedScans: 0,
        crawlSource: 'cloud-run'
      };
    } catch (error) {
      this.logger.warn('Failed to create single product from card', {
        baseName,
        error: error.message
      });
      return null;
    }
  }
}

module.exports = PoppateaSpecializedCrawler;
