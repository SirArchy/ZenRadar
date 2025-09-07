const PoppateaSpecializedCrawler = require('./src/crawlers/poppatea-crawler');

// Mock logger
const mockLogger = {
    info: (msg, data) => console.log('INFO:', msg, data ? JSON.stringify(data) : ''),
    warn: (msg, data) => console.log('WARN:', msg, data ? JSON.stringify(data) : ''),
    error: (msg, data) => console.log('ERROR:', msg, data ? JSON.stringify(data) : '')
};

async function testPoppateaCrawler() {
    console.log('=== Testing Updated Poppatea Crawler ===');
    
    const crawler = new PoppateaSpecializedCrawler(mockLogger);
    
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

testPoppateaCrawler();
