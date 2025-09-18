/**
 * Debug script to identify Yoshien duplicate product extraction
 */
const axios = require('axios');
const cheerio = require('cheerio');

async function debugYoshienDuplicates() {
    try {
        console.log('🔍 Debugging Yoshien duplicate products...');
        
        const response = await axios.get('https://www.yoshien.com/matcha', {
            timeout: 30000,
            headers: {
                'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.5',
                'Accept-Encoding': 'gzip, deflate',
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache'
            }
        });

        const $ = cheerio.load(response.data);
        
        // Debug: Check all possible product selectors
        const productSelectors = [
            '.cs-product-tile',
            '.product-item',
            '.grid-item',
            '.item'
        ];
        
        for (const selector of productSelectors) {
            const elements = $(selector);
            console.log(`\n📊 Selector '${selector}': ${elements.length} elements found`);
            
            if (elements.length > 0) {
                // Extract first few products to see structure
                for (let i = 0; i < Math.min(elements.length, 5); i++) {
                    const element = $(elements[i]);
                    
                    // Try different name selectors
                    const nameSelectors = [
                        'a.product-item-link',
                        '.product-item-name a',
                        '.product-name',
                        'h2 a',
                        'h3 a'
                    ];
                    
                    let name = null;
                    for (const nameSelector of nameSelectors) {
                        const nameElement = element.find(nameSelector);
                        if (nameElement.length) {
                            name = nameElement.text().trim();
                            if (name) {
                                console.log(`  📝 Product ${i + 1} (${nameSelector}): "${name}"`);
                                break;
                            }
                        }
                    }
                    
                    // Try to get URL
                    const linkElement = element.find('a.product-item-link');
                    let productUrl = null;
                    if (linkElement.length) {
                        const href = linkElement.attr('href');
                        if (href) {
                            productUrl = href.startsWith('http') ? href : 'https://www.yoshien.com' + href;
                            console.log(`  🔗 URL: ${productUrl}`);
                        }
                    }
                    
                    // Generate ID as the crawler would
                    const cleanName = name ? name.toLowerCase().replace(/[^a-z0-9]/g, '') : '';
                    let productId;
                    if (productUrl) {
                        const urlPath = productUrl.replace('https://www.yoshien.com', '').replace(/^\//, '');
                        if (urlPath.includes('/')) {
                            const pathParts = urlPath.split('/');
                            const lastPart = pathParts[pathParts.length - 1];
                            productId = `yoshien_${lastPart}_${cleanName}`.substring(0, 100);
                        } else {
                            productId = `yoshien_${cleanName}`.substring(0, 100);
                        }
                    } else {
                        productId = `yoshien_${cleanName}`.substring(0, 100);
                    }
                    
                    console.log(`  🆔 Product ID: ${productId}`);
                    
                    // Check for price
                    const priceElement = element.find('.price');
                    if (priceElement.length) {
                        console.log(`  💰 Price: "${priceElement.text().trim()}"`);
                    }
                    
                    console.log('  ────────────────────────');
                }
            }
        }
        
        // Now let's specifically check for duplicates using the main selector
        console.log('\n🔍 Checking for duplicates with main selector (.cs-product-tile)...');
        const mainElements = $('.cs-product-tile');
        const seenProducts = new Set();
        const duplicates = [];
        
        for (let i = 0; i < mainElements.length; i++) {
            const element = $(mainElements[i]);
            
            // Extract name using the same logic as the crawler
            let name = null;
            const nameSelectors = [
                'a.product-item-link',
                '.product-item-name a',
                '.product-name',
                'h2 a',
                'h3 a'
            ];
            
            for (const selector of nameSelectors) {
                const nameElement = element.find(selector);
                if (nameElement.length) {
                    name = nameElement.text().trim();
                    if (name) break;
                }
            }
            
            if (name) {
                // Check if this is a matcha product
                const isMatcha = ['matcha', 'green tea powder', 'ceremonial grade', 'premium grade', 'culinary grade']
                    .some(keyword => name.toLowerCase().includes(keyword));
                
                if (isMatcha) {
                    // Generate product ID
                    const linkElement = element.find('a.product-item-link');
                    let productUrl = null;
                    if (linkElement.length) {
                        const href = linkElement.attr('href');
                        if (href) {
                            productUrl = href.startsWith('http') ? href : 'https://www.yoshien.com' + href;
                        }
                    }
                    
                    const cleanName = name.toLowerCase().replace(/[^a-z0-9]/g, '');
                    let productId;
                    if (productUrl) {
                        const urlPath = productUrl.replace('https://www.yoshien.com', '').replace(/^\//, '');
                        if (urlPath.includes('/')) {
                            const pathParts = urlPath.split('/');
                            const lastPart = pathParts[pathParts.length - 1];
                            productId = `yoshien_${lastPart}_${cleanName}`.substring(0, 100);
                        } else {
                            productId = `yoshien_${cleanName}`.substring(0, 100);
                        }
                    } else {
                        productId = `yoshien_${cleanName}`.substring(0, 100);
                    }
                    
                    if (seenProducts.has(productId)) {
                        duplicates.push({
                            productId,
                            name,
                            index: i,
                            url: productUrl
                        });
                        console.log(`❌ DUPLICATE found: "${name}" (ID: ${productId}) at index ${i}`);
                    } else {
                        seenProducts.add(productId);
                        console.log(`✅ UNIQUE: "${name}" (ID: ${productId}) at index ${i}`);
                    }
                }
            }
        }
        
        console.log(`\n📊 Summary:`);
        console.log(`   Total product elements: ${mainElements.length}`);
        console.log(`   Unique matcha products: ${seenProducts.size}`);
        console.log(`   Duplicates found: ${duplicates.length}`);
        
        if (duplicates.length > 0) {
            console.log('\n❌ Duplicate details:');
            duplicates.forEach((dup, index) => {
                console.log(`   ${index + 1}. "${dup.name}" (ID: ${dup.productId}) at index ${dup.index}`);
            });
        }
        
    } catch (error) {
        console.error('❌ Debug failed:', error.message);
    }
}

debugYoshienDuplicates();