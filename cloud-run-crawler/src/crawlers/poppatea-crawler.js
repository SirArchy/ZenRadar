const axios = require('axios');
const cheerio = require('cheerio');
const { v4: uuidv4 } = require('uuid');
const sharp = require('sharp');
const { getStorage } = require('firebase-admin/storage');

class PoppateaSpecializedCrawler {
    constructor(logger) {
        this.logger = logger;
        this.baseUrl = 'https://poppatea.com';
        this.siteName = 'Poppatea';
        this.storage = getStorage();
        
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
        
        this.sekToEurRate = 0.086;
    }
    
    async crawl(categoryUrl, config) {
        return await this.crawlProducts(categoryUrl, config);
    }

    async crawlProducts(categoryUrl = null, config = null) {
        // Poppatea has 3 main tea products - crawl each directly
        const productUrls = [
            'https://poppatea.com/de-de/products/matcha-tea-ceremonial',
            'https://poppatea.com/de-de/products/matcha-tea-with-chai-ceremonial', 
            'https://poppatea.com/de-de/products/hojicha-tea-powder'
        ];
        
        if (this.logger && this.logger.info) {
            this.logger.info('Starting Poppatea crawl for ' + productUrls.length + ' individual products');
        }
        
        const results = [];

        for (const productUrl of productUrls) {
            try {
                if (this.logger && this.logger.info) {
                    this.logger.info('Fetching product: ' + productUrl);
                }
                
                const response = await this.fetchWithRetry(productUrl);
                
                if (!response.ok) {
                    if (this.logger && this.logger.error) {
                        this.logger.error('Failed to fetch ' + productUrl + ': ' + response.status + ' ' + response.statusText);
                    }
                    continue;
                }
                
                const html = await response.text();
                if (this.logger && this.logger.info) {
                    this.logger.info('HTML length for ' + productUrl + ': ' + html.length);
                }

                // Extract product image from HTML
                let productImage = null;
                try {
                    // Extract all matching images and find the best one for this product
                    const allImageMatches = [...html.matchAll(/<img[^>]+src="((?:https:)?\/\/poppatea\.com\/cdn\/shop\/files\/[^"]*\.jpg[^"]*)"[^>]*>/gi)];
                    
                    for (const match of allImageMatches) {
                        let imgUrl = match[1];
                        // Normalize protocol-relative URLs
                        if (imgUrl.startsWith('//')) {
                            imgUrl = 'https:' + imgUrl;
                        }
                        const imgName = imgUrl.toLowerCase();
                        
                        // Match specific product images based on URL content
                        if (productUrl.includes('matcha-tea-ceremonial') && !productUrl.includes('chai')) {
                            if (imgName.includes('matcha_tea') && !imgName.includes('chai')) {
                                productImage = imgUrl;
                                break;
                            }
                        } else if (productUrl.includes('matcha-tea-with-chai')) {
                            if (imgName.includes('matcha_tea_with_chai') || (imgName.includes('chai') && imgName.includes('matcha'))) {
                                productImage = imgUrl;
                                break;
                            }
                        } else if (productUrl.includes('hojicha-tea-powder')) {
                            if (imgName.includes('hojicha')) {
                                productImage = imgUrl;
                                break;
                            }
                        }
                    }
                    
                    // Clean up URL parameters for consistency  
                    if (productImage && productImage.includes('?')) {
                        productImage = productImage.split('?')[0];
                    }
                    
                    if (productImage && this.logger && this.logger.info) {
                        this.logger.info('Found product image for ' + productUrl + ': ' + productImage);
                    }
                } catch (imageError) {
                    if (this.logger && this.logger.warn) {
                        this.logger.warn('Failed to extract image from ' + productUrl + ': ' + imageError.message);
                    }
                }

                const variantsPattern = /"variants"\s*:\s*(\[.*?\])/s;
                let variantsMatch = html.match(variantsPattern);
                
                // Try alternative patterns if first one doesn't work
                if (!variantsMatch) {
                    const altPattern1 = /variants:\s*(\[.*?\])/s;
                    variantsMatch = html.match(altPattern1);
                }
                
                if (!variantsMatch) {
                    const altPattern2 = /window\.ShopifyAnalytics\.meta\.product\.variants\s*=\s*(\[.*?\])/s;
                    variantsMatch = html.match(altPattern2);
                }
                
                if (!variantsMatch) {
                    if (this.logger && this.logger.info) {
                        this.logger.info('No variants found for ' + productUrl);
                    }
                    continue;
                }

                try {
                    const variants = JSON.parse(variantsMatch[1]);
                    if (this.logger && this.logger.info) {
                        this.logger.info('Found ' + variants.length + ' variants for ' + productUrl);
                        // Log first variant for debugging with full structure
                        if (variants.length > 0) {
                            const variant = variants[0];
                            this.logger.info('Sample variant structure:', {
                                id: variant.id,
                                name: variant.name || variant.title,
                                available: variant.available,
                                price: variant.price,
                                product_id: variant.product_id,
                                sku: variant.sku,
                                featured_image: variant.featured_image ? 'has_image' : 'no_image',
                                public_title: variant.public_title,
                                all_keys: Object.keys(variant)
                            });
                        }
                    }
                    
                    const productGroups = this.groupVariantsByProduct(variants);
                    if (this.logger && this.logger.info) {
                        this.logger.info('Grouped ' + productUrl + ' into ' + Object.keys(productGroups).length + ' product groups');
                    }
                    
                    for (const [productTitle, productVariants] of Object.entries(productGroups)) {
                        if (this.logger && this.logger.info) {
                            this.logger.info(`Creating products for: ${productTitle} (${productVariants.length} variants)`);
                        }
                        
                        for (const variant of productVariants) {
                            const product = await this.createVariantProduct(variant, productTitle, productImage);
                            if (product) {
                                if (this.logger && this.logger.info) {
                                    this.logger.info(`Created product: ${product.id} - ${product.name}`);
                                }
                                results.push(product);
                            }
                        }
                    }
                    
                } catch (parseError) {
                    if (this.logger && this.logger.error) {
                        this.logger.error('Error parsing variants JSON for ' + productUrl + ': ' + parseError.message);
                    }
                }
                
            } catch (error) {
                if (this.logger && this.logger.error) {
                    this.logger.error('Error crawling product ' + productUrl + ': ' + error.message);
                }
            }
        }

        if (this.logger && this.logger.info) {
            this.logger.info('Poppatea crawl completed. Found ' + results.length + ' products.');
        }
        return { products: results };
    }

    async fetchWithRetry(url, maxRetries = 3, retryDelay = 2000) {
        for (let attempt = 1; attempt <= maxRetries; attempt++) {
            try {
                const response = await axios.get(url, this.requestConfig);
                return {
                    ok: response.status >= 200 && response.status < 300,
                    status: response.status,
                    statusText: response.statusText,
                    text: async () => response.data
                };
            } catch (error) {
                if (attempt === maxRetries) {
                    throw error;
                }
                
                if (this.logger && this.logger.warn) {
                    this.logger.warn('Fetch attempt ' + attempt + ' failed, retrying... ' + error.message);
                }
                
                await new Promise(resolve => setTimeout(resolve, retryDelay));
            }
        }
    }

    groupVariantsByProduct(variants) {
        const groups = {};
        
        for (const variant of variants) {
            // Note: Poppatea structure changed - now uses 'name' instead of 'title' and no 'available' field
            // We assume variants are available if they're listed
            const variantName = variant.name || variant.title || '';
            if (variant.price && variantName) {
                // Filter for matcha and hojicha products
                const name = variantName.toLowerCase();
                if (name.includes('matcha') || name.includes('match') || name.includes('hojicha') || name.includes('hoji')) {
                    const baseTitle = this.extractBaseTitle(variantName);
                    
                    // Log for debugging
                    if (this.logger && this.logger.info) {
                        this.logger.info(`Processing variant: ${variantName} -> Base: ${baseTitle}`);
                    }
                    
                    if (!groups[baseTitle]) {
                        groups[baseTitle] = [];
                    }
                    groups[baseTitle].push(variant);
                } else {
                    // Log filtered out products for debugging
                    if (this.logger && this.logger.info) {
                        this.logger.info(`Filtered out non-matcha variant: ${variantName}`);
                    }
                }
            } else {
                // Log variants without price or name
                if (this.logger && this.logger.info) {
                    this.logger.info(`Skipped variant without price or name:`, {
                        id: variant.id,
                        price: variant.price,
                        name: variantName,
                        hasName: !!variantName,
                        hasPrice: !!variant.price
                    });
                }
            }
        }
        
        return groups;
    }

    extractBaseTitle(name) {
        // Remove variant-specific suffixes to get base product name
        return name
            .replace(/\s*-\s*(50g|100g|Dose|Nachfüllbeutel|2x50g|2 x 50 g).*$/, '')
            .replace(/\s*\(\d+\s*Portionen?\).*$/, '') // Remove portion info
            .replace(/\s*-\s*\d+g.*$/, '') // Remove size info like "- 50g"
            .trim();
    }

    async createVariantProduct(variant, baseTitle, productImage = null) {
        try {
            const priceInEuros = (variant.price || 0) / 100;
            
            // Get the variant name with fallback
            const variantName = variant.name || variant.title || baseTitle;
            
            // Map the base title to the correct product URL for consistent ID generation
            let productSlug = this.getProductSlugFromTitle(baseTitle);
            
            const productUrl = `https://poppatea.com/de-de/products/${productSlug}`;
            const productId = this.generateVariantProductId(variant, baseTitle);
            
            // Try to get product image
            let imageUrl = null;
            if (productImage) {
                try {
                    // Process and upload the image to Firebase Storage
                    imageUrl = await this.downloadAndStoreImage(productImage, productId);
                } catch (imageError) {
                    if (this.logger && this.logger.warn) {
                        this.logger.warn('Failed to process Poppatea product image', { 
                            productId, 
                            variant: variant.name, 
                            error: imageError.message 
                        });
                    }
                }
            } else if (variant.featured_image) {
                // Fallback to variant image if available
                try {
                    let processedImageUrl = variant.featured_image.url || variant.featured_image;
                    if (processedImageUrl.startsWith('//')) {
                        processedImageUrl = 'https:' + processedImageUrl;
                    }
                    // Process and upload the image to Firebase Storage
                    imageUrl = await this.downloadAndStoreImage(processedImageUrl, productId);
                } catch (imageError) {
                    if (this.logger && this.logger.warn) {
                        this.logger.warn('Failed to process Poppatea variant image', { 
                            productId, 
                            variant: variant.name, 
                            error: imageError.message 
                        });
                    }
                }
            }
            
            return {
                id: productId,
                name: variantName || baseTitle,
                normalizedName: this.normalizeName(variantName || baseTitle),
                site: 'poppatea',
                siteName: this.siteName,
                price: '€' + priceInEuros.toFixed(2),
                originalPrice: '€' + priceInEuros.toFixed(2),
                priceValue: priceInEuros,
                currency: 'EUR',
                url: productUrl,
                imageUrl: imageUrl || null,
                isInStock: true, // Assume available if listed (no availability field in new structure)
                category: 'Matcha',
                lastChecked: new Date(),
                lastUpdated: new Date(),
                firstSeen: new Date(),
                isDiscontinued: false,
                missedScans: 0,
                crawlSource: 'specialized',
                productId: variant.id ? variant.id.toString() : null,
                metadata: {
                    variantId: variant.id || null,
                    productId: variant.product_id || null,
                    sku: variant.sku || null,
                    publicTitle: variant.public_title || null
                }
            };
        } catch (error) {
            if (this.logger && this.logger.error) {
                this.logger.error('Error creating variant product: ' + error.message);
            }
            return null;
        }
    }

    getProductSlugFromTitle(title) {
        const titleLower = title.toLowerCase();
        
        // Map specific product titles to their URL slugs
        if (titleLower.includes('matcha tee') && titleLower.includes('zeremoniell') && !titleLower.includes('chai')) {
            return 'matcha-tea-ceremonial';
        }
        if (titleLower.includes('matcha tee') && titleLower.includes('chai') && titleLower.includes('zeremoniell')) {
            return 'matcha-tea-with-chai-ceremonial';
        }
        if (titleLower.includes('hojicha') || titleLower.includes('hoji')) {
            return 'hojicha-tea-powder';
        }
        
        // Fallback: create slug from title
        return title.toLowerCase()
            .replace(/[^\w\s-]/g, '')
            .replace(/\s+/g, '-')
            .replace(/--+/g, '-')
            .replace(/^-+|-+$/g, '');
    }

    getProductNameForId(name) {
        const nameLower = name.toLowerCase();
        
        // Map specific product names to their expected ID name parts
        if (nameLower.includes('matcha tee') && nameLower.includes('zeremoniell') && !nameLower.includes('chai')) {
            return 'Matcha Tee Zeremoniell';
        }
        if (nameLower.includes('matcha tee') && nameLower.includes('chai') && nameLower.includes('zeremoniell')) {
            return 'Matcha Tee mit Chai Zere'; // Truncated to match expected ID
        }
        if (nameLower.includes('hojicha') || nameLower.includes('hoji')) {
            return 'Hojichatee Pulver'; // Use the German name for the ID
        }
        
        return name;
    }

    generateProductId(url, name) {
        const slug = this.getProductSlugFromTitle(name);
        const productName = this.getProductNameForId(name);
        
        const slugPart = slug.replace(/-/g, '');
        const namePart = productName.toLowerCase().replace(/[^\w]/g, '');
        
        return `poppatea_${slugPart}_${namePart}`;
    }

    generateVariantProductId(variant, baseTitle) {
        const slug = this.getProductSlugFromTitle(baseTitle);
        const productName = this.getProductNameForId(baseTitle);
        
        const slugPart = slug.replace(/-/g, '');
        const namePart = productName.toLowerCase().replace(/[^\w]/g, '');
        const variantId = variant.id || 'unknown';
        
        return `poppatea_${slugPart}_${namePart}_${variantId}`;
    }

    normalizeName(name) {
        if (!name) return '';
        return name
            .toLowerCase()
            .replace(/[^\w\s]/g, ' ')
            .replace(/\s+/g, ' ')
            .trim();
    }

    /**
     * Download and compress image, then upload to Firebase Storage
     */
    async downloadAndStoreImage(imageUrl, productId) {
        try {
            if (!imageUrl || imageUrl.includes('data:') || imageUrl.includes('placeholder')) {
                return null;
            }

            // Check if image already exists in Firebase Storage
            const fileName = `product-images/poppatea/${productId}.jpg`;
            const file = this.storage.bucket().file(fileName);
            
            try {
                const [exists] = await file.exists();
                if (exists) {
                    // Image already exists, return the existing URL
                    const bucketName = this.storage.bucket().name;
                    // Handle bucket names that already include .firebasestorage.app
                    const cleanBucketName = bucketName.replace('.firebasestorage.app', '');
                    const publicUrl = `https://storage.googleapis.com/${cleanBucketName}.firebasestorage.app/${fileName}`;
                    if (this.logger && this.logger.info) {
                        this.logger.info('Using existing Poppatea image from storage', { 
                            productId, 
                            publicUrl 
                        });
                    }
                    return publicUrl;
                }
            } catch (existsError) {
                // If checking existence fails, proceed to download
                if (this.logger && this.logger.warn) {
                    this.logger.warn('Failed to check if Poppatea image exists, proceeding to download', { 
                        productId, 
                        error: existsError.message 
                    });
                }
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
                if (this.logger && this.logger.warn) {
                    this.logger.warn('Invalid image URL format', { productId, imageUrl: absoluteUrl });
                }
                return null;
            }

            if (this.logger && this.logger.info) {
                this.logger.info('Downloading Poppatea image', { 
                    productId, 
                    imageUrl: absoluteUrl 
                });
            }

            // Download image with improved error handling
            const response = await axios({
                method: 'GET',
                url: absoluteUrl,
                responseType: 'arraybuffer',
                timeout: 20000,
                maxRedirects: 5,
                headers: {
                    'User-Agent': this.requestConfig.headers['User-Agent'],
                    'Accept': 'image/*',
                }
            });

            // Validate response
            if (!response.data || response.data.length === 0) {
                if (this.logger && this.logger.warn) {
                    this.logger.warn('Empty image response', { productId, imageUrl: absoluteUrl });
                }
                return null;
            }

            // Check if response is actually an image
            const contentType = response.headers['content-type'];
            if (contentType && !contentType.startsWith('image/')) {
                if (this.logger && this.logger.warn) {
                    this.logger.warn('Response is not an image', { 
                        productId, 
                        imageUrl: absoluteUrl, 
                        contentType 
                    });
                }
                return null;
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
                if (this.logger && this.logger.warn) {
                    this.logger.warn('Failed to process image with Sharp', {
                        productId,
                        imageUrl: absoluteUrl,
                        error: sharpError.message
                    });
                }
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
            
            if (this.logger && this.logger.info) {
                this.logger.info('Poppatea image uploaded successfully', { 
                    productId, 
                    publicUrl,
                    originalSize: response.data.length,
                    compressedSize: compressedImageBuffer.length
                });
            }

            return publicUrl;

        } catch (error) {
            if (this.logger && this.logger.error) {
                this.logger.error('Failed to download and store Poppatea image', {
                    productId,
                    imageUrl,
                    error: error.message
                });
            }
            return null;
        }
    }

}

module.exports = PoppateaSpecializedCrawler;
