const axios = require('axios');

// Simplified version of the Poppatea crawler for testing
class SimplePoppateaCrawler {
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
    }
    
    async crawl() {
        const targetUrl = 'https://poppatea.com/de-de/collections/all-teas';
        const results = [];

        try {
            const response = await this.fetchWithRetry(targetUrl);
            
            if (!response.ok) {
                console.log('Failed to fetch:', response.status, response.statusText);
                return { products: results };
            }
            
            const html = await response.text();
            console.log('HTML length:', html.length);

            const variantsPattern = /"variants"\s*:\s*(\[.*?\])/s;
            const variantsMatch = html.match(variantsPattern);
            
            if (!variantsMatch) {
                console.log('No variants found with regex pattern');
                return { products: results };
            }

            const variants = JSON.parse(variantsMatch[1]);
            console.log('Found', variants.length, 'variants');
            
            const productGroups = this.groupVariantsByProduct(variants);
            console.log('Grouped into', Object.keys(productGroups).length, 'products');
            
            for (const [productTitle, productVariants] of Object.entries(productGroups)) {
                console.log(`Creating products for: ${productTitle} (${productVariants.length} variants)`);
                
                for (const variant of productVariants) {
                    const product = this.createVariantProduct(variant, productTitle);
                    if (product) {
                        console.log(`Created product: ${product.id} - ${product.name}`);
                        results.push(product);
                    }
                }
            }
            
        } catch (error) {
            console.error('Error crawling Poppatea:', error.message);
        }

        console.log('Poppatea crawl completed. Found', results.length, 'products.');
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
                console.log('Fetch attempt', attempt, 'failed, retrying...', error.message);
                await new Promise(resolve => setTimeout(resolve, retryDelay));
            }
        }
    }

    groupVariantsByProduct(variants) {
        const groups = {};
        
        for (const variant of variants) {
            // Note: Poppatea structure changed - now uses 'name' instead of 'title' and no 'available' field
            // We assume variants are available if they're listed
            if (variant.price && variant.name) {
                // Filter for matcha and hojicha products
                const name = variant.name.toLowerCase();
                if (name.includes('matcha') || name.includes('match') || name.includes('hojicha') || name.includes('hoji')) {
                    const baseTitle = this.extractBaseTitle(variant.name);
                    
                    console.log(`Processing variant: ${variant.name} -> Base: ${baseTitle}`);
                    
                    if (!groups[baseTitle]) {
                        groups[baseTitle] = [];
                    }
                    groups[baseTitle].push(variant);
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

    createVariantProduct(variant, baseTitle) {
        try {
            const priceInEuros = variant.price / 100;
            
            // Map the base title to the correct product URL for consistent ID generation
            let productSlug = this.getProductSlugFromTitle(baseTitle);
            
            const productUrl = `https://poppatea.com/de-de/products/${productSlug}`;
            const productId = this.generateVariantProductId(variant, baseTitle);
            
            return {
                id: productId,
                name: variant.name || baseTitle,
                normalizedName: this.normalizeName(variant.name || baseTitle),
                site: 'poppatea',
                siteName: this.siteName,
                price: '€' + priceInEuros.toFixed(2),
                originalPrice: '€' + priceInEuros.toFixed(2),
                priceValue: priceInEuros,
                currency: 'EUR',
                url: productUrl,
                imageUrl: null, // Skip image processing for test
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
                    variantId: variant.id,
                    productId: variant.product_id,
                    sku: variant.sku,
                    publicTitle: variant.public_title
                }
            };
        } catch (error) {
            console.error('Error creating variant product:', error.message);
            return null;
        }
    }

    getProductSlugFromTitle(name) {
        const nameLower = name.toLowerCase();
        
        // Map specific product names to their URL slugs
        if (nameLower.includes('matcha tee') && nameLower.includes('zeremoniell') && !nameLower.includes('chai')) {
            return 'matcha-tea-ceremonial';
        }
        if (nameLower.includes('matcha tee') && nameLower.includes('chai') && nameLower.includes('zeremoniell')) {
            return 'matcha-tea-with-chai-ceremonial';
        }
        if (nameLower.includes('hojicha') || nameLower.includes('hoji')) {
            return 'hojicha-tea-powder';
        }
        
        // Fallback: create slug from name
        return name.toLowerCase()
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
}

async function testSimplePoppateaCrawler() {
    console.log('=== Testing Simple Poppatea Crawler ===');
    
    const crawler = new SimplePoppateaCrawler();
    
    try {
        const result = await crawler.crawl();
        
        console.log('\n=== Crawl Results ===');
        console.log('Total products found:', result.products.length);
        
        result.products.forEach((product, index) => {
            console.log(`\nProduct ${index + 1}:`);
            console.log('  ID:', product.id);
            console.log('  Name:', product.name);
            console.log('  Price:', product.price);
            console.log('  In Stock:', product.isInStock);
            console.log('  URL:', product.url);
            console.log('  SKU:', product.metadata?.sku);
        });
        
    } catch (error) {
        console.error('Crawler test failed:', error.message);
    }
}

testSimplePoppateaCrawler();
