const axios = require('axios');
const cheerio = require('cheerio');

async function debugYoshienStockUpdates() {
    console.log('🔍 Debugging Yoshien Stock Update Logic...\n');
    
    try {
        const categoryUrl = 'https://www.yoshien.com/matcha';
        
        const requestConfig = {
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

        console.log('📄 Fetching Yoshien category page...');
        const response = await axios.get(categoryUrl, requestConfig);
        const $ = cheerio.load(response.data);
        
        console.log(`✅ Status: ${response.status}`);
        console.log(`📋 Page title: ${$('title').text()}\n`);
        
        // Find product cards using Yoshien's expected selector
        const productCards = $('.cs-product-tile');
        console.log(`🛍️ Found ${productCards.length} product cards\n`);
        
        if (productCards.length === 0) {
            console.log('❌ No products found with selector .cs-product-tile');
            console.log('🔍 Let\'s check what selectors are available...');
            
            // Look for common product container selectors
            const commonSelectors = [
                '.product-item',
                '.product-card',
                '.product-tile',
                '.item',
                '[class*="product"]',
                '[class*="item"]'
            ];
            
            for (const selector of commonSelectors) {
                const elements = $(selector);
                if (elements.length > 0) {
                    console.log(`   ${selector}: ${elements.length} elements`);
                }
            }
            return;
        }
        
        // Test first few products to understand ID generation and data consistency
        const maxProducts = Math.min(5, productCards.length);
        const productData = [];
        
        for (let i = 0; i < maxProducts; i++) {
            const productElement = $(productCards[i]);
            console.log(`--- Testing Product ${i + 1} ---`);
            
            // Simulate Yoshien crawler's product extraction
            const nameSelectors = [
                'a.product-item-link',
                '.product-item-name a',
                '.product-name',
                'h2 a',
                'h3 a'
            ];
            
            let productName = null;
            for (const selector of nameSelectors) {
                const nameElement = productElement.find(selector);
                if (nameElement.length) {
                    productName = nameElement.text().trim();
                    if (productName) {
                        console.log(`📦 Product name (${selector}): ${productName}`);
                        break;
                    }
                }
            }
            
            // Extract product URL for ID generation
            let productUrl = null;
            const linkElement = productElement.find('a.product-item-link');
            if (linkElement.length) {
                const href = linkElement.attr('href');
                if (href) {
                    productUrl = href.startsWith('http') ? href : 'https://www.yoshien.com' + href;
                    console.log(`🔗 Product URL: ${productUrl}`);
                }
            }
            
            // Generate ID using Yoshien's logic
            if (productName && productUrl) {
                const baseUrl = 'https://www.yoshien.com';
                const urlPath = productUrl.replace(baseUrl, '').replace(/^\//, '');
                const cleanName = productName.toLowerCase().replace(/[^a-z0-9]/g, '');
                
                let productId;
                if (urlPath.includes('/')) {
                    const pathParts = urlPath.split('/');
                    const lastPart = pathParts[pathParts.length - 1];
                    productId = `yoshien_${lastPart}_${cleanName}`.substring(0, 100);
                } else {
                    productId = `yoshien_${cleanName}`.substring(0, 100);
                }
                
                console.log(`🆔 Generated ID: ${productId}`);
                
                // Extract price
                const priceElement = productElement.find('.price');
                const rawPrice = priceElement.text().trim();
                console.log(`💰 Raw price: "${rawPrice}"`);
                
                // Check stock status
                const outOfStockSelectors = [
                    '.stock.unavailable',
                    '.out-of-stock',
                    ':contains("nicht verfügbar")',
                    ':contains("ausverkauft")',
                    ':contains("sold out")'
                ];
                
                let isInStock = true;
                for (const selector of outOfStockSelectors) {
                    if (productElement.find(selector).length > 0) {
                        isInStock = false;
                        break;
                    }
                }
                
                // If price is present, assume in stock (Magento default behavior)
                if (priceElement.length > 0 && priceElement.text().trim()) {
                    isInStock = true;
                }
                
                console.log(`📊 Stock status: ${isInStock ? 'In Stock' : 'Out of Stock'}`);
                
                productData.push({
                    id: productId,
                    name: productName,
                    url: productUrl,
                    price: rawPrice,
                    isInStock: isInStock
                });
            }
            
            console.log(''); // Empty line for separation
        }
        
        // Run the same extraction again to see if IDs are consistent
        console.log('\n🔄 Running second extraction to check ID consistency...\n');
        
        for (let i = 0; i < maxProducts; i++) {
            const productElement = $(productCards[i]);
            console.log(`--- Re-testing Product ${i + 1} ---`);
            
            // Use same logic as before
            let productName = null;
            const nameSelectors = [
                'a.product-item-link',
                '.product-item-name a',
                '.product-name',
                'h2 a',
                'h3 a'
            ];
            
            for (const selector of nameSelectors) {
                const nameElement = productElement.find(selector);
                if (nameElement.length) {
                    productName = nameElement.text().trim();
                    if (productName) break;
                }
            }
            
            let productUrl = null;
            const linkElement = productElement.find('a.product-item-link');
            if (linkElement.length) {
                const href = linkElement.attr('href');
                if (href) {
                    productUrl = href.startsWith('http') ? href : 'https://www.yoshien.com' + href;
                }
            }
            
            if (productName && productUrl) {
                const baseUrl = 'https://www.yoshien.com';
                const urlPath = productUrl.replace(baseUrl, '').replace(/^\//, '');
                const cleanName = productName.toLowerCase().replace(/[^a-z0-9]/g, '');
                
                let productId;
                if (urlPath.includes('/')) {
                    const pathParts = urlPath.split('/');
                    const lastPart = pathParts[pathParts.length - 1];
                    productId = `yoshien_${lastPart}_${cleanName}`.substring(0, 100);
                } else {
                    productId = `yoshien_${cleanName}`.substring(0, 100);
                }
                
                const originalProduct = productData[i];
                const idsMatch = originalProduct.id === productId;
                const namesMatch = originalProduct.name === productName;
                
                console.log(`🆔 ID consistency: ${idsMatch ? '✅' : '❌'} (${productId})`);
                console.log(`📦 Name consistency: ${namesMatch ? '✅' : '❌'}`);
                
                if (!idsMatch) {
                    console.log(`   Original ID: ${originalProduct.id}`);
                    console.log(`   New ID: ${productId}`);
                }
                
                if (!namesMatch) {
                    console.log(`   Original name: ${originalProduct.name}`);
                    console.log(`   New name: ${productName}`);
                }
            }
            
            console.log(''); // Empty line for separation
        }
        
        console.log('🎯 Analysis Summary:');
        console.log(`- Found ${productCards.length} total products`);
        console.log(`- Tested ${maxProducts} products for consistency`);
        console.log('- This helps identify if ID generation is causing false "new product" updates');
        
    } catch (error) {
        console.error('❌ Debug failed:', error.message);
        if (error.response) {
            console.error(`Response status: ${error.response.status}`);
            console.error(`Response headers:`, error.response.headers);
        }
    }
}

debugYoshienStockUpdates();