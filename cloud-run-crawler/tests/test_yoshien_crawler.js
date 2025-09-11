/**
 * Test file for Yoshien crawler (updated version)
 * Tests product extraction, image processing, and Firebase integration
 */

const YoshienCrawler = require('./src/crawlers/yoshien-crawler');

async function testYoshienCrawler() {
    console.log('=== Testing Yoshien Crawler ===\n');
    
    // Create a simple logger for testing
    const testLogger = {
        info: (msg, data) => console.log(`[INFO] ${msg}`, data || ''),
        error: (msg, data) => console.log(`[ERROR] ${msg}`, data || ''),
        warn: (msg, data) => console.log(`[WARN] ${msg}`, data || ''),
        debug: (msg, data) => console.log(`[DEBUG] ${msg}`, data || '')
    };
    
    const crawler = new YoshienCrawler(testLogger);
    
    try {
        // Test URL accessibility
        console.log('1. Testing site accessibility...');
        const testResponse = await fetch('https://www.yoshien.com/matcha');
        console.log(`✅ Site accessible: ${testResponse.status} ${testResponse.statusText}\n`);
        
        // Test basic crawling functionality
        console.log('2. Testing product extraction...');
        
        // Use the proper yoshien configuration
        const config = {
            name: 'Yoshi En',
            baseUrl: 'https://www.yoshien.com',
            categoryUrl: 'https://www.yoshien.com/matcha',
            productSelector: '.cs-product-tile',
            nameSelector: 'a.product-item-link',
            priceSelector: '.price',
            stockSelector: '.price',
            linkSelector: 'a.product-item-link',
            imageSelector: '.cs-product-tile__image img, .product-image-photo',
            stockKeywords: ['€'],
            outOfStockKeywords: ['nicht verfügbar', 'ausverkauft', 'sold out'],
            currency: 'EUR',
            currencySymbol: '€'
        };
        
        const result = await crawler.crawl(config.categoryUrl, config);
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
            
            // Test lazy loading image handling (specific to Yoshien)
            console.log('\n5. Testing lazy loading image handling...');
            const axios = require('axios');
            const cheerio = require('cheerio');
            
            try {
                const response = await axios.get('https://www.yoshien.com/collections/matcha');
                const $ = cheerio.load(response.data);
                
                const imageElements = $('.product-item-photo img').slice(0, 3);
                console.log('Image element attributes:');
                
                imageElements.each((index, element) => {
                    const $img = $(element);
                    const src = $img.attr('src');
                    const dataSrc = $img.attr('data-src');
                    console.log(`  Image ${index + 1}:`);
                    console.log(`    src: ${src}`);
                    console.log(`    data-src: ${dataSrc}`);
                    
                    if (src && src.includes('data:image')) {
                        console.log(`    ✅ Properly skipping base64 placeholder`);
                    }
                    if (dataSrc && dataSrc.includes('media.yoshien.com')) {
                        console.log(`    ✅ Found real image URL in data-src`);
                    }
                });
                
            } catch (imgTestError) {
                console.log('Image attribute test failed:', imgTestError.message);
            }
            
        } else {
            console.log('⚠️ No products found - may need to check selectors');
        }
        
    } catch (error) {
        console.error('❌ Crawler test failed:', error.message);
        if (error.stack) {
            console.error('Stack trace:', error.stack);
        }
    }
    
    console.log('\n=== Yoshien Crawler Test Complete ===');
}

// Run the test
testYoshienCrawler().catch(console.error);
