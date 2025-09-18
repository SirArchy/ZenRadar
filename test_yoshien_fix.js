/**
 * Test the fixed Yoshien crawler to verify duplicate prevention
 */
const YoshienSpecializedCrawler = require('./cloud-run-crawler/src/crawlers/yoshien-crawler');

// Mock logger
const logger = {
    info: (msg, data) => console.log(`INFO: ${msg}`, data || ''),
    warn: (msg, data) => console.log(`WARN: ${msg}`, data || ''),
    error: (msg, data) => console.log(`ERROR: ${msg}`, data || '')
};

async function testYoshienFix() {
    try {
        console.log('🧪 Testing fixed Yoshien crawler...');
        
        const crawler = new YoshienSpecializedCrawler(logger);
        const config = crawler.getConfig();
        
        // Test crawl with duplicate detection
        const result = await crawler.crawl(config.categoryUrl, config);
        
        console.log('\n📊 Test Results:');
        console.log(`   Products found: ${result.products.length}`);
        
        // Check for duplicates in the results
        const productIds = result.products.map(p => p.id);
        const uniqueIds = new Set(productIds);
        
        console.log(`   Unique product IDs: ${uniqueIds.size}`);
        console.log(`   Duplicates in results: ${productIds.length - uniqueIds.size}`);
        
        if (productIds.length === uniqueIds.size) {
            console.log('✅ SUCCESS: No duplicates found in results!');
        } else {
            console.log('❌ FAILURE: Duplicates still present in results');
        }
        
        // Show first few product names for verification
        console.log('\n📝 First 10 products:');
        result.products.slice(0, 10).forEach((product, index) => {
            console.log(`   ${index + 1}. ${product.name} (${product.id})`);
        });
        
    } catch (error) {
        console.error('❌ Test failed:', error.message);
    }
}

testYoshienFix();