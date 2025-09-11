/**
 * Generate updated test files with proper logger setup
 */

const fs = require('fs');
const path = require('path');

const crawlerConfigs = [
    {
        name: 'Emeri',
        className: 'EmeriCrawler',
        testUrl: 'https://emeri.co.uk/collections/matcha-powder',
        fileName: 'test_emeri_crawler.js',
        crawlerFile: './src/crawlers/emeri-crawler'
    },
    {
        name: 'Horiishichimeien', 
        className: 'HoriishichimeienCrawler',
        testUrl: 'https://horiishichimeien.com/collections/matcha',
        fileName: 'test_horiishichimeien_crawler.js',
        crawlerFile: './src/crawlers/horiishichimeien-crawler'
    },
    {
        name: 'Ippodo Tea',
        className: 'IppodoTeaCrawler', 
        testUrl: 'https://global.ippodo-tea.co.jp/collections/matcha',
        fileName: 'test_ippodo_tea_crawler.js',
        crawlerFile: './src/crawlers/ippodo-tea-crawler'
    },
    {
        name: 'Marukyu Koyamaen',
        className: 'MarukyuKoyamaenCrawler',
        testUrl: 'https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha',
        fileName: 'test_marukyu_koyamaen_crawler.js',
        crawlerFile: './src/crawlers/marukyu-koyamaen-crawler'
    },
    {
        name: 'Matcha Karu',
        className: 'MatchaKaruCrawler',
        testUrl: 'https://matchakaru.com/collections/matcha-powder', 
        fileName: 'test_matcha_karu_crawler.js',
        crawlerFile: './src/crawlers/matcha-karu-crawler'
    },
    {
        name: 'Nakamura Tokichi',
        className: 'NakamuraToukichiCrawler',
        testUrl: 'https://www.tokichi.jp/global/item/matcha/',
        fileName: 'test_nakamura_tokichi_crawler.js',
        crawlerFile: './src/crawlers/nakamura-tokichi-crawler'
    },
    {
        name: 'Poppatea',
        className: 'PoppateaCrawler',
        testUrl: 'https://poppatea.com/collections/matcha',
        fileName: 'test_poppatea_crawler.js', 
        crawlerFile: './src/crawlers/poppatea-crawler'
    },
    {
        name: 'Sazentea',
        className: 'SazenteaCrawler',
        testUrl: 'https://sazentea.com/collections/matcha',
        fileName: 'test_sazentea_crawler.js',
        crawlerFile: './src/crawlers/sazentea-crawler'
    },
    {
        name: 'Sho Cha',
        className: 'ShoCrawler',
        testUrl: 'https://sho-cha.com/collections/matcha',
        fileName: 'test_sho_cha_crawler.js',
        crawlerFile: './src/crawlers/sho-cha-crawler'
    }
];

function generateTestFile(config) {
    return `/**
 * Test file for ${config.name} crawler
 * Tests product extraction, image processing, and Firebase integration
 */

const ${config.className} = require('${config.crawlerFile}');

async function test${config.className}() {
    console.log('=== Testing ${config.name} Crawler ===\\n');
    
    // Create a simple logger for testing
    const testLogger = {
        info: (msg, data) => console.log(\`[INFO] \${msg}\`, data || ''),
        error: (msg, data) => console.log(\`[ERROR] \${msg}\`, data || ''),
        warn: (msg, data) => console.log(\`[WARN] \${msg}\`, data || ''),
        debug: (msg, data) => console.log(\`[DEBUG] \${msg}\`, data || '')
    };
    
    const crawler = new ${config.className}(testLogger);
    
    try {
        // Test URL accessibility
        console.log('1. Testing site accessibility...');
        const testResponse = await fetch('${config.testUrl}');
        console.log(\`✅ Site accessible: \${testResponse.status} \${testResponse.statusText}\\n\`);
        
        // Test basic crawling functionality
        console.log('2. Testing product extraction...');
        const result = await crawler.crawl();
        const products = result.products || [];
        
        console.log(\`📊 Found \${products.length} products\`);
        
        if (products.length > 0) {
            // Show first few products
            console.log('\\n📋 Sample products:');
            products.slice(0, 3).forEach((product, index) => {
                console.log(\`\${index + 1}. \${product.name}\`);
                console.log(\`   Price: \${product.price}\`);
                console.log(\`   URL: \${product.url}\`);
                console.log(\`   Image: \${product.imageUrl || 'missing'}\`);
                console.log(\`   In Stock: \${product.inStock}\`);
                console.log('');
            });
            
            // Test image extraction specifically
            console.log('3. Testing image extraction...');
            const productsWithImages = products.filter(p => p.imageUrl && p.imageUrl !== 'missing' && !p.imageUrl.startsWith('data:'));
            console.log(\`✅ Products with valid images: \${productsWithImages.length}/\${products.length}\`);
            
            if (productsWithImages.length > 0) {
                console.log('Sample image URLs:');
                productsWithImages.slice(0, 3).forEach((product, index) => {
                    console.log(\`  \${index + 1}. \${product.imageUrl}\`);
                });
            }
            
            // Test stock detection
            console.log('\\n4. Testing stock detection...');
            const inStockProducts = products.filter(p => p.inStock);
            const outOfStockProducts = products.filter(p => !p.inStock);
            console.log(\`✅ In stock: \${inStockProducts.length}\`);
            console.log(\`❌ Out of stock: \${outOfStockProducts.length}\`);
            
        } else {
            console.log('⚠️ No products found - may need to check selectors');
        }
        
    } catch (error) {
        console.error('❌ Crawler test failed:', error.message);
        if (error.stack) {
            console.error('Stack trace:', error.stack);
        }
    }
    
    console.log('\\n=== ${config.name} Crawler Test Complete ===');
}

// Run the test
test${config.className}().catch(console.error);`;
}

// Generate all test files
crawlerConfigs.forEach(config => {
    const content = generateTestFile(config);
    fs.writeFileSync(config.fileName, content);
    console.log(`✅ Generated ${config.fileName}`);
});

console.log('\\n🎉 All test files generated successfully!');
