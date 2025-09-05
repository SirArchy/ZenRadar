const axios = require('axios');
const cheerio = require('cheerio');
const { v4: uuidv4 } = require('uuid');

class PoppateaSpecializedCrawler {
    constructor(logger) {
        this.logger = logger;
        this.baseUrl = 'https://poppatea.com';
        this.siteName = 'Poppatea';
        
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
        // Use the correct German URL for Poppatea with all matcha products
        const targetUrl = 'https://poppatea.com/de-de/collections/all-teas';
        
        if (this.logger && this.logger.info) {
            this.logger.info('Starting Poppatea crawl from ' + targetUrl + ' (German all-teas collection)');
        }
        
        const results = [];

        try {
            if (this.logger && this.logger.info) {
                this.logger.info('Fetching collection: ' + targetUrl);
            }
            
            const response = await this.fetchWithRetry(targetUrl);
            
            if (!response.ok) {
                if (this.logger && this.logger.error) {
                    this.logger.error('Failed to fetch ' + targetUrl + ': ' + response.status + ' ' + response.statusText);
                }
                return { products: results };
            }
            
            const html = await response.text();
            if (this.logger && this.logger.info) {
                this.logger.info('HTML length: ' + html.length);
                // Log if we can find any products or variants in the HTML
                const hasProducts = html.includes('product') || html.includes('Product');
                const hasVariants = html.includes('variants') || html.includes('variant');
                const hasMatcha = html.includes('matcha') || html.includes('Matcha');
                this.logger.info('HTML content analysis: products=' + hasProducts + ', variants=' + hasVariants + ', matcha=' + hasMatcha);
            }

            const variantsPattern = /"variants"\s*:\s*(\[.*?\])/s;
            const variantsMatch = html.match(variantsPattern);
            
            if (!variantsMatch) {
                if (this.logger && this.logger.info) {
                    this.logger.info('No variants found with regex pattern');
                }
                return { products: results };
            }

            try {
                const variants = JSON.parse(variantsMatch[1]);
                if (this.logger && this.logger.info) {
                    this.logger.info('Found ' + variants.length + ' variants');
                }
                
                const productGroups = this.groupVariantsByProduct(variants);
                if (this.logger && this.logger.info) {
                    this.logger.info('Grouped into ' + Object.keys(productGroups).length + ' products');
                }
                
                for (const [productTitle, productVariants] of Object.entries(productGroups)) {
                    for (const variant of productVariants) {
                        const product = this.createVariantProduct(variant, productTitle);
                        if (product) {
                            results.push(product);
                        }
                    }
                }
                
            } catch (parseError) {
                if (this.logger && this.logger.error) {
                    this.logger.error('Error parsing variants JSON: ' + parseError.message);
                }
            }
            
        } catch (error) {
            if (this.logger && this.logger.error) {
                this.logger.error('Error crawling Poppatea: ' + error.message);
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
            if (variant.available && variant.price && variant.title) {
                // Filter for matcha products only
                const title = variant.title.toLowerCase();
                if (title.includes('matcha') || title.includes('match')) {
                    const baseTitle = this.extractBaseTitle(variant.title);
                    if (!groups[baseTitle]) {
                        groups[baseTitle] = [];
                    }
                    groups[baseTitle].push(variant);
                }
            }
        }
        
        return groups;
    }

    extractBaseTitle(title) {
        return title.replace(/\s*-\s*(50g|100g|Dose|Nachfüllbeutel|2x50g).*$/, '').trim();
    }

    createVariantProduct(variant, baseTitle) {
        try {
            const priceInEuros = variant.price / 100;
            
            return {
                id: this.generateProductId(variant.id, variant.title),
                name: variant.title || baseTitle,
                normalizedName: this.normalizeName(variant.title || baseTitle),
                site: 'poppatea',
                siteName: this.siteName,
                price: '€' + priceInEuros.toFixed(2),
                originalPrice: '€' + priceInEuros.toFixed(2),
                priceValue: priceInEuros,
                currency: 'EUR',
                url: 'https://poppatea.com/de-de/products/' + (variant.product_id || 'unknown'),
                imageUrl: null,
                isInStock: variant.available ? true : false,
                category: 'Matcha',
                lastChecked: new Date(),
                lastUpdated: new Date(),
                firstSeen: new Date(),
                isDiscontinued: false,
                missedScans: 0,
                crawlSource: 'specialized',
                productId: variant.id ? variant.id.toString() : null,
                metadata: {
                    variantId: variant.id,
                    productId: variant.product_id,
                    inventoryQuantity: variant.inventory_quantity,
                    sku: variant.sku
                }
            };
        } catch (error) {
            if (this.logger && this.logger.error) {
                this.logger.error('Error creating variant product: ' + error.message);
            }
            return null;
        }
    }

    generateProductId(variantId, productName) {
        const cleanName = productName && productName.toLowerCase && productName.toLowerCase().replace && 
                         productName.toLowerCase().replace(/[^\w]/g, '_') || 'unknown';
        return ('poppatea_' + variantId + '_' + cleanName).substring(0, 100);
    }

    normalizeName(name) {
        if (!name) return '';
        return name
            .toLowerCase()
            .replace(/[^\w\s]/g, ' ')
            .replace(/\s+/g, ' ')
            .trim();
    }

}

module.exports = PoppateaSpecializedCrawler;