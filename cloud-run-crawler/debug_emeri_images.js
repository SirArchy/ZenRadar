const axios = require('axios');
const cheerio = require('cheerio');

async function debugEmeriImages() {
    console.log('🔍 Debugging Emeri image extraction...');
    
    try {
        // Test if dependencies are working
        console.log('✅ Dependencies loaded successfully');
        
        // Test the specific failing product
        const testUrl = 'https://enjoyemeri.com/products/ceramic-matcha-bowl?variant=45648240902196';
        const categoryUrl = 'https://www.enjoyemeri.com/collections/shop-all';
        
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

        console.log('\n=== Testing Product Page ===');
        console.log(`URL: ${testUrl}`);
        
        const response = await axios.get(testUrl, requestConfig);
        const $ = cheerio.load(response.data);
        
        console.log(`Status: ${response.status}`);
        console.log(`Page title: ${$('title').text()}`);
        
        // Test current selectors used in the crawler
        console.log('\n=== Testing Current Crawler Selectors ===');
        const currentSelectors = [
            '.product-media__image img',
            '.product-card__image img',
            '.product-image img',
            '.card__media img',
            'img[src*="products/"]'
        ];
        
        for (const selector of currentSelectors) {
            const imgs = $(selector);
            console.log(`Selector "${selector}": Found ${imgs.length} elements`);
            imgs.each((i, el) => {
                const src = $(el).attr('src');
                const alt = $(el).attr('alt');
                console.log(`  [${i}] src: ${src}, alt: ${alt}`);
            });
        }
        
        // Find ALL img tags to see what's available
        console.log('\n=== All IMG Tags Analysis ===');
        const allImgs = $('img');
        console.log(`Total img tags found: ${allImgs.length}`);
        
        allImgs.each((i, el) => {
            const src = $(el).attr('src');
            const alt = $(el).attr('alt');
            const classes = $(el).attr('class');
            const dataSrc = $(el).attr('data-src');
            const dataSrcset = $(el).attr('data-srcset');
            
            if (src && (src.includes('cdn.shopify.com') || src.includes('enjoyemeri') || src.includes('product'))) {
                console.log(`\n[IMG ${i}] POTENTIAL PRODUCT IMAGE:`);
                console.log(`  src: ${src}`);
                console.log(`  alt: ${alt}`);
                console.log(`  class: ${classes}`);
                console.log(`  data-src: ${dataSrc}`);
                console.log(`  data-srcset: ${dataSrcset}`);
            }
        });
        
        // Check for lazy loading patterns
        console.log('\n=== Lazy Loading Patterns ===');
        const lazyImages = $('img[data-src], img[data-srcset], img[loading="lazy"]');
        console.log(`Lazy loaded images found: ${lazyImages.length}`);
        lazyImages.each((i, el) => {
            const src = $(el).attr('src');
            const dataSrc = $(el).attr('data-src');
            const dataSrcset = $(el).attr('data-srcset');
            console.log(`  [${i}] src: ${src}, data-src: ${dataSrc}, data-srcset: ${dataSrcset}`);
        });
        
        // Check for Shopify-specific patterns
        console.log('\n=== Shopify CDN Images ===');
        const shopifyImages = $('img[src*="cdn.shopify.com"]');
        console.log(`Shopify CDN images found: ${shopifyImages.length}`);
        shopifyImages.each((i, el) => {
            const src = $(el).attr('src');
            const alt = $(el).attr('alt');
            console.log(`  [${i}] ${src} (alt: ${alt})`);
        });
        
        console.log('\n✅ Debug completed successfully');
        
    } catch (error) {
        console.error('❌ Error debugging Emeri images:', error.message);
        console.error('Stack trace:', error.stack);
        if (error.response) {
            console.error(`Response status: ${error.response.status}`);
            console.error(`Response headers:`, error.response.headers);
        }
    }
}

// Run the debug function
debugEmeriImages().catch(console.error);
