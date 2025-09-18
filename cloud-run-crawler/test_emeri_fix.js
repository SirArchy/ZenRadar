const axios = require('axios');
const cheerio = require('cheerio');

async function testFixedEmeriExtraction() {
    console.log('🧪 Testing Fixed Emeri Image Extraction...');
    
    try {
        console.log('📡 Making request to Emeri...');
        const testUrl = 'https://enjoyemeri.com/products/ceramic-matcha-bowl?variant=45648240902196';
        
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

        const response = await axios.get(testUrl, requestConfig);
        const $ = cheerio.load(response.data);
        
        console.log(`✅ Loaded page: ${$('title').text()}`);
        console.log(`📄 Response status: ${response.status}`);
        
        // Test the improved selectors
        const improvedSelectors = [
            'img.product-media__image',  // Direct class on img tag
            '.product-media__image img', // Original selector as fallback
            '.product-card__image img',
            '.product-image img',
            '.card__media img',
            'img[src*="cdn/shop/files/"]', // Emeri specific CDN path
            'img[alt*="Matcha"], img[alt*="Bowl"], img[alt*="Whisk"]' // Alt text based
        ];
        
        console.log('\n=== Testing Improved Selectors ===');
        
        let foundImage = null;
        
        for (const selector of improvedSelectors) {
            console.log(`\n🔍 Testing selector: "${selector}"`);
            const imgs = $(selector);
            console.log(`   Found ${imgs.length} elements`);
            
            if (imgs.length > 0) {
                imgs.each((i, el) => {
                    const img = $(el);
                    let imageUrl = img.attr('src') || img.attr('data-src');
                    const alt = img.attr('alt');
                    console.log(`   [${i}] src: ${imageUrl}, alt: ${alt}`);
                    
                    if (imageUrl && !foundImage) {
                        // Apply the same logic as the fixed crawler
                        if (imageUrl.startsWith('//')) {
                            imageUrl = 'https:' + imageUrl;
                        }
                        
                        if (imageUrl.includes('cdn.shop') || imageUrl.includes('enjoyemeri')) {
                            const cleanUrl = imageUrl.split('?')[0] + '?width=800';
                            console.log(`   ✅ SELECTED: ${cleanUrl}`);
                            foundImage = cleanUrl;
                        }
                    }
                });
                
                if (foundImage) break;
            }
        }
        
        if (foundImage) {
            console.log(`\n🎉 SUCCESS! Selected image: ${foundImage}`);
            
            // Test if the image URL is accessible
            try {
                console.log('🌐 Testing image accessibility...');
                const imageResponse = await axios.head(foundImage, { timeout: 10000 });
                console.log(`✅ Image is accessible (Status: ${imageResponse.status})`);
                console.log(`📏 Content-Length: ${imageResponse.headers['content-length']} bytes`);
                console.log(`🖼️ Content-Type: ${imageResponse.headers['content-type']}`);
            } catch (imageError) {
                console.log(`❌ Image not accessible: ${imageError.message}`);
            }
        } else {
            console.log('\n❌ No valid image found with improved selectors');
        }
        
    } catch (error) {
        console.error('❌ Test failed:', error.message);
        console.error('Stack:', error.stack);
    }
}

// Add error handling and explicit execution
testFixedEmeriExtraction().catch(console.error).finally(() => {
    console.log('\n🏁 Test completed');
});
