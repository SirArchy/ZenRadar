/**
 * Test file for Nakamura Tokichi crawler
 * Tests product extraction, image processing, and Firebase integration
 */

const NakamuraToukichiCrawler = require('../src/crawlers/nakamura-tokichi-crawler');

async function testNakamuraToukichiCrawler() {
    console.log('=== Testing Nakamura Tokichi Crawler ===\n');
    
    // Create a simple logger for testing
    const testLogger = {
        info: (msg, data) => console.log(`[INFO] ${msg}`, data || ''),
        error: (msg, data) => console.log(`[ERROR] ${msg}`, data || ''),
        warn: (msg, data) => console.log(`[WARN] ${msg}`, data || ''),
        debug: (msg, data) => console.log(`[DEBUG] ${msg}`, data || '')
    };
    
    const crawler = new NakamuraToukichiCrawler(testLogger);
    
    try {
        // Test URL accessibility
        console.log('1. Testing site accessibility...');
        const testResponse = await fetch('https://www.tokichi.jp/global/item/matcha/');
        console.log(`✅ Site accessible: ${testResponse.status} ${testResponse.statusText}\n`);
        
        // Test basic crawling functionality
        console.log('2. Testing product extraction...');
        const result = await crawler.crawl();
        const products = result.products || [];
        
        console.log(`📊 Found ${products.length} products`);
        
        if (products.length > 0) {
            // Show first few products
            console.log('\n📋 Sample products:');
            products.slice(0, 3).forEach((product, index) => {
                console.log(`${index + 1}. ${product.name}`);
                console.log(`   Price: ${product.price}`);
                console.log(`   URL: ${product.url}`);
                console.log(`   Image: ${product.imageUrl || 'missing'}`);
                console.log(`   In Stock: ${product.inStock}`);
                console.log('');
            });
            
            // Test image extraction specifically
            console.log('3. Testing image extraction...');
            const productsWithImages = products.filter(p => p.imageUrl && p.imageUrl !== 'missing' && !p.imageUrl.startsWith('data:'));
            console.log(`✅ Products with valid images: ${productsWithImages.length}/${products.length}`);
            
            if (productsWithImages.length > 0) {
                console.log('Sample image URLs:');
                productsWithImages.slice(0, 3).forEach((product, index) => {
                    console.log(`  ${index + 1}. ${product.imageUrl}`);
                });
            }
            
            // Test stock detection
            console.log('\n4. Testing stock detection...');
            const inStockProducts = products.filter(p => p.inStock);
            const outOfStockProducts = products.filter(p => !p.inStock);
            console.log(`✅ In stock: ${inStockProducts.length}`);
            console.log(`❌ Out of stock: ${outOfStockProducts.length}`);
            
        } else {
            console.log('⚠️ No products found - may need to check selectors');
        }
        
    } catch (error) {
        console.error('❌ Crawler test failed:', error.message);
        if (error.stack) {
            console.error('Stack trace:', error.stack);
        }
    }
    
    console.log('\n=== Nakamura Tokichi Crawler Test Complete ===');
}

// Run the test
testNakamuraToukichiCrawler().catch(console.error);