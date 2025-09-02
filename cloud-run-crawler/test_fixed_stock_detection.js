const axios = require('axios');
const cheerio = require('cheerio');

// Mock logger
const mockLogger = {
  info: (msg, data) => console.log(`INFO: ${msg}`, data),
  warn: (msg, data) => console.log(`WARN: ${msg}`, data),
  error: (msg, data) => console.log(`ERROR: ${msg}`, data)
};

const HoriishichimeienCrawler = require('./src/crawlers/horiishichimeien-crawler.js');

async function testFixedStockDetection() {
  console.log('🔧 Testing FIXED Horiishichimeien stock detection...');
  
  const crawler = new HoriishichimeienCrawler(mockLogger);
  
  try {
    // Get first few products using the crawler
    const result = await crawler.crawlProducts();
    
    if (result && result.products) {
      console.log(`\n📦 Found ${result.products.length} products with FIXED stock detection`);
      
      // Count in stock vs out of stock
      const inStock = result.products.filter(p => p.isInStock);
      const outOfStock = result.products.filter(p => !p.isInStock);
      
      console.log(`\n📊 Stock Summary:`);
      console.log(`✅ In Stock: ${inStock.length}`);
      console.log(`❌ Out of Stock: ${outOfStock.length}`);
      console.log(`📈 Stock Rate: ${((inStock.length / result.products.length) * 100).toFixed(1)}%`);
      
      // Show first 5 in stock products
      if (inStock.length > 0) {
        console.log(`\n✅ First 5 IN STOCK products:`);
        inStock.slice(0, 5).forEach((product, i) => {
          console.log(`  ${i + 1}. ${product.name} - ${product.price} (${product.url})`);
        });
      }
      
      // Show first 5 out of stock products  
      if (outOfStock.length > 0) {
        console.log(`\n❌ First 5 OUT OF STOCK products:`);
        outOfStock.slice(0, 5).forEach((product, i) => {
          console.log(`  ${i + 1}. ${product.name} - ${product.price} (${product.url})`);
        });
      }
      
      // Check if we have a reasonable stock distribution
      if (inStock.length > 0) {
        console.log(`\n🎉 SUCCESS: Fixed stock detection! Found ${inStock.length} products in stock.`);
      } else {
        console.log(`\n⚠️  WARNING: Still showing all products as out of stock. Need further investigation.`);
      }
      
    } else {
      console.log('❌ No products returned from crawler');
    }
    
  } catch (error) {
    console.error('❌ Error testing fixed stock detection:', error.message);
  }
}

testFixedStockDetection();
