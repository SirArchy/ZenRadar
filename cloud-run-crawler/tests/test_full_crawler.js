const PoppateaCrawler = require('../src/crawlers/poppatea-crawler');

// Mock logger
const mockLogger = {
    info: (...args) => console.log('[INFO]', ...args),
    warn: (...args) => console.warn('[WARN]', ...args),
    error: (...args) => console.error('[ERROR]', ...args)
};

// Mock Firebase storage methods
const mockStorage = {
    downloadAndStoreImage: async (url, filename) => {
        console.log(`[MOCK] Would download image ${url} as ${filename}`);
        return `https://storage.googleapis.com/zenradar-images/${filename}`;
    }
};

async function testPoppateaCrawler() {
    console.log('=== Testing Poppatea Crawler ===');
    
    const crawler = new PoppateaCrawler(mockLogger);
    
    // Override the downloadAndStoreImage method to avoid actual Firebase calls
    crawler.downloadAndStoreImage = mockStorage.downloadAndStoreImage;
    
    try {
        const results = await crawler.crawl();
        console.log('\n=== Crawl Results ===');
        console.log(`Found ${results.length} products`);
        
        results.forEach((product, index) => {
            console.log(`\nProduct ${index + 1}:`);
            console.log(`  Name: ${product.name}`);
            console.log(`  Price: €${(product.price / 100).toFixed(2)}`);
            console.log(`  SKU: ${product.sku}`);
            console.log(`  Image URL: ${product.imageUrl || 'null'}`);
            console.log(`  Available: ${product.available}`);
        });
        
    } catch (error) {
        console.error('Error during crawl:', error);
    }
}

testPoppateaCrawler();
