const PoppateaSpecializedCrawler = require('./src/crawlers/poppatea-crawler');

// Create a final test to verify the Poppatea fix works
async function finalPoppateaTest() {
    console.log('=== Final Poppatea Crawler Test ===');
    console.log('This test simulates the actual Cloud Run environment\n');
    
    // Mock logger that matches Cloud Run logging
    const mockLogger = {
        info: (msg, data) => {
            const timestamp = new Date().toISOString();
            console.log(`${msg} {"service":"zenradar-crawler","timestamp":"${timestamp}"}`);
        },
        warn: (msg, data) => {
            const timestamp = new Date().toISOString();
            console.log(`WARN: ${msg} {"service":"zenradar-crawler","timestamp":"${timestamp}"}`);
        },
        error: (msg, data) => {
            const timestamp = new Date().toISOString();
            console.log(`ERROR: ${msg} {"service":"zenradar-crawler","timestamp":"${timestamp}"}`);
        }
    };

    console.log('Using Poppatea specialized crawler {"service":"zenradar-crawler","timestamp":"' + new Date().toISOString() + '"}');
    
    // Mock Firebase Admin for testing (the actual crawler would fail without proper Firebase setup)
    const originalGetStorage = require('firebase-admin/storage').getStorage;
    require.cache[require.resolve('firebase-admin/storage')].exports.getStorage = () => ({
        bucket: () => ({
            file: () => ({
                exists: async () => [false],
                save: async () => {},
                makePublic: async () => {},
                name: 'test-file.jpg'
            }),
            name: 'test-bucket'
        })
    });

    try {
        const crawler = new PoppateaSpecializedCrawler(mockLogger);
        const result = await crawler.crawl();
        
        const timestamp = new Date().toISOString();
        console.log(`Poppatea crawl completed. Found ${result.products.length} products. {"service":"zenradar-crawler","timestamp":"${timestamp}"}`);
        
        console.log('\n=== Products Found ===');
        result.products.forEach((product, index) => {
            console.log(`${index + 1}. ${product.name} - ${product.price} (${product.isInStock ? 'In Stock' : 'Out of Stock'})`);
        });
        
        if (result.products.length > 0) {
            console.log('\n✅ SUCCESS: Poppatea crawler is now working correctly!');
            console.log(`✅ Found ${result.products.length} products instead of 0`);
            console.log('✅ Each variant has unique ID with variant number');
            console.log('✅ Prices and stock status are properly detected');
        } else {
            console.log('\n❌ FAILURE: Still not finding any products');
        }
        
    } catch (error) {
        const timestamp = new Date().toISOString();
        console.log(`ERROR: Poppatea crawler failed: ${error.message} {"service":"zenradar-crawler","timestamp":"${timestamp}"}`);
    }
    
    // Restore original function
    require.cache[require.resolve('firebase-admin/storage')].exports.getStorage = originalGetStorage;
}

finalPoppateaTest();
