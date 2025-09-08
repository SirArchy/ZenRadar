// Test script for Poppatea crawler without Firebase dependencies
const axios = require('axios');

class TestPoppateaCrawler {
    constructor() {
        this.logger = console;
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
    
    async crawlProducts() {
        // Poppatea has 3 main tea products - crawl each directly
        const productUrls = [
            'https://poppatea.com/de-de/products/matcha-tea-ceremonial',
            'https://poppatea.com/de-de/products/matcha-tea-with-chai-ceremonial', 
            'https://poppatea.com/de-de/products/hojicha-tea-powder'
        ];
        
        console.log('🔍 Starting Poppatea crawl for', productUrls.length, 'individual products');
        
        const results = [];

        for (let i = 0; i < productUrls.length; i++) {
            const productUrl = productUrls[i];
            try {
                console.log(`\n📡 [${i + 1}/${productUrls.length}] Fetching:`, productUrl);
                
                const response = await this.fetchWithRetry(productUrl);
                
                if (!response.ok) {
                    console.error('❌ Failed to fetch:', response.status, response.statusText);
                    continue;
                }
                
                const html = await response.text();
                console.log('📄 HTML length:', html.length);
                
                // Look for variants pattern
                const variantsPattern = /"variants"\s*:\s*(\[.*?\])/s;
                let variantsMatch = html.match(variantsPattern);
                
                if (!variantsMatch) {
                    console.log('❌ No variants found for this product');
                    continue;
                }

                console.log('✅ Variants found! Parsing...');
                
                try {
                    const variants = JSON.parse(variantsMatch[1]);
                    console.log('📦 Found', variants.length, 'variants');
                    
                    // Log all variants with their structure
                    variants.forEach((variant, index) => {
                        const variantName = variant.name || variant.title || 'No name';
                        console.log(`\n  📋 Variant ${index + 1}:`, variantName);
                        console.log('    🆔 ID:', variant.id);
                        console.log('    💰 Price:', variant.price);
                        console.log('    📊 Available:', variant.available);
                        console.log('    🔗 Product ID:', variant.product_id);
                        console.log('    📦 SKU:', variant.sku);
                        console.log('    🖼️  Image:', variant.featured_image ? 'Yes' : 'No');
                        console.log('    🏷️  Public title:', variant.public_title);
                    });
                    
                    // Group variants by product
                    const productGroups = this.groupVariantsByProduct(variants);
                    console.log('\n  🗂️  Grouped into', Object.keys(productGroups).length, 'product groups');
                    
                    Object.entries(productGroups).forEach(([baseTitle, productVariants]) => {
                        console.log(`    📁 "${baseTitle}": ${productVariants.length} variants`);
                    });
                    
                    // Create products from variants
                    for (const [productTitle, productVariants] of Object.entries(productGroups)) {
                        console.log(`\n  🏭 Creating products for: "${productTitle}"`);
                        
                        for (const variant of productVariants) {
                            const product = this.createVariantProduct(variant, productTitle);
                            if (product) {
                                console.log(`    ✅ Created: ${product.id} - ${product.name}`);
                                results.push(product);
                            } else {
                                console.log(`    ❌ Failed to create product for variant:`, variant.name || variant.title);
                            }
                        }
                    }
                    
                } catch (parseError) {
                    console.error('❌ Error parsing variants JSON:', parseError.message);
                }
                
            } catch (error) {
                console.error('❌ Error crawling product:', error.message);
            }
        }

        console.log('\n🎉 Poppatea crawl completed!');
        console.log('📊 Total products found:', results.length);
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
                
                console.warn(`⚠️  Fetch attempt ${attempt} failed, retrying...`, error.message);
                await new Promise(resolve => setTimeout(resolve, retryDelay));
            }
        }
    }

    groupVariantsByProduct(variants) {
        const groups = {};
        
        console.log('\n🔍 Analyzing variants for matcha/hojicha products...');
        
        for (const variant of variants) {
            const variantName = variant.name || variant.title || '';
            
            if (variant.price && variantName) {
                const name = variantName.toLowerCase();
                console.log(`  🔍 Checking: "${variantName}"`);
                console.log(`    Contains matcha: ${name.includes('matcha')}`);
                console.log(`    Contains match: ${name.includes('match')}`);
                console.log(`    Contains hojicha: ${name.includes('hojicha')}`);
                console.log(`    Contains hoji: ${name.includes('hoji')}`);
                
                if (name.includes('matcha') || name.includes('match') || name.includes('hojicha') || name.includes('hoji')) {
                    const baseTitle = this.extractBaseTitle(variantName);
                    console.log(`    ✅ MATCH! Base title: "${baseTitle}"`);
                    
                    if (!groups[baseTitle]) {
                        groups[baseTitle] = [];
                    }
                    groups[baseTitle].push(variant);
                } else {
                    console.log(`    ❌ No match - filtered out`);
                }
            } else {
                console.log(`  ❌ Skipped variant (no price or name):`, {
                    id: variant.id,
                    hasPrice: !!variant.price,
                    hasName: !!variantName
                });
            }
        }
        
        return groups;
    }

    extractBaseTitle(name) {
        return name
            .replace(/\s*-\s*(50g|100g|Dose|Nachfüllbeutel|2x50g|2 x 50 g).*$/, '')
            .replace(/\s*\(\d+\s*Portionen?\).*$/, '')
            .replace(/\s*-\s*\d+g.*$/, '')
            .trim();
    }

    createVariantProduct(variant, baseTitle) {
        try {
            const priceInEuros = (variant.price || 0) / 100;
            const variantName = variant.name || variant.title || baseTitle;
            const productId = `poppatea_${variant.id || 'unknown'}`;
            
            return {
                id: productId,
                name: variantName || baseTitle,
                price: '€' + priceInEuros.toFixed(2),
                priceValue: priceInEuros,
                currency: 'EUR',
                isInStock: true,
                category: 'Matcha',
                site: 'poppatea',
                metadata: {
                    variantId: variant.id || null,
                    productId: variant.product_id || null,
                    sku: variant.sku || null,
                    publicTitle: variant.public_title || null
                }
            };
        } catch (error) {
            console.error('❌ Error creating variant product:', error.message);
            return null;
        }
    }
}

// Run the test
async function runTest() {
    const crawler = new TestPoppateaCrawler();
    const result = await crawler.crawlProducts();
    
    console.log('\n' + '='.repeat(50));
    console.log('📊 FINAL RESULTS');
    console.log('='.repeat(50));
    console.log('Total products:', result.products.length);
    
    result.products.forEach((product, i) => {
        console.log(`\n${i + 1}. ${product.name}`);
        console.log(`   ID: ${product.id}`);
        console.log(`   Price: ${product.price}`);
        console.log(`   Metadata:`, product.metadata);
    });
}

runTest().catch(console.error);
