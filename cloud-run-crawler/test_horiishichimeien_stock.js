const HoriishichimeienSpecializedCrawler = require('./src/crawlers/horiishichimeien-crawler.js');
const axios = require('axios');
const cheerio = require('cheerio');

async function testHoriishichimeienStock() {
  console.log('🧪 Testing Horishichimeien stock detection...\n');
  
  // Create mock logger
  const mockLogger = {
    info: (msg, data) => console.log(`INFO: ${msg}`, data || ''),
    warn: (msg, data) => console.log(`WARN: ${msg}`, data || ''),
    error: (msg, data) => console.log(`ERROR: ${msg}`, data || '')
  };
  
  const crawler = new HoriishichimeienSpecializedCrawler(mockLogger);
  
  try {
    // Test the actual crawling
    console.log('📡 Fetching actual products from Horishichimeien...');
    const products = await crawler.crawl();
    
    console.log(`✅ Found ${products.length} products\n`);
    
    // Show first 5 products with detailed stock info
    console.log('📊 Stock status for first 5 products:');
    products.slice(0, 5).forEach((product, index) => {
      console.log(`${index + 1}. ${product.name}`);
      console.log(`   Stock: ${product.isInStock ? '✅ In Stock' : '❌ Out of Stock'}`);
      console.log(`   Price: ${product.price || 'No price'}`);
      console.log(`   URL: ${product.url}`);
      console.log('');
    });
    
    // Count stock status
    const inStock = products.filter(p => p.isInStock).length;
    const outOfStock = products.filter(p => !p.isInStock).length;
    
    console.log('📈 Stock Summary:');
    console.log(`   In Stock: ${inStock}`);
    console.log(`   Out of Stock: ${outOfStock}`);
    console.log(`   Total: ${products.length}`);
    
    if (outOfStock === products.length) {
      console.log('\n⚠️  WARNING: All products showing as out of stock!');
      console.log('   This suggests an issue with stock detection logic.');
      
      // Let's test stock detection on a specific product page
      await testSpecificProductStock(crawler);
    } else {
      console.log('\n✅ Stock detection appears to be working correctly.');
    }
    
  } catch (error) {
    console.error('❌ Error testing Horishichimeien stock:', error.message);
  }
}

async function testSpecificProductStock(crawler) {
  console.log('\n🔍 Testing stock detection on a specific product...');
  
  try {
    // Get the collection page first
    const response = await axios.get('https://horiishichimeien.com/collections/matcha', {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      }
    });
    
    const $ = cheerio.load(response.data);
    
    // Find first product element
    const productElement = $('.grid-view-item').first();
    
    if (productElement.length === 0) {
      console.log('❌ No product elements found on page');
      return;
    }
    
    console.log('🔍 Analyzing first product element:');
    
    // Check what text is in the element
    const elementText = productElement.text();
    console.log('📄 Element text:', elementText.substring(0, 200) + '...');
    
    // Check for stock indicators
    const stockSelectors = [
      '.product-form__buttons',
      '.product-form', 
      'form[action="/cart/add"]',
      'button[name="add"]',
      '.money',
      '.price'
    ];
    
    console.log('\n🔍 Checking stock selectors:');
    stockSelectors.forEach(selector => {
      const found = productElement.find(selector);
      console.log(`   ${selector}: ${found.length > 0 ? '✅ Found' : '❌ Not found'}`);
    });
    
    // Test the stock detection method
    const isInStock = crawler.determineStockStatus($, productElement);
    console.log(`\n📊 Stock detection result: ${isInStock ? '✅ In Stock' : '❌ Out of Stock'}`);
    
    // Check for out of stock keywords
    const outOfStockKeywords = ['sold out', 'unavailable', '売り切れ', 'out of stock'];
    console.log('\n🔍 Checking for out of stock keywords:');
    outOfStockKeywords.forEach(keyword => {
      const found = elementText.toLowerCase().includes(keyword);
      console.log(`   "${keyword}": ${found ? '⚠️ Found' : '✅ Not found'}`);
    });
    
  } catch (error) {
    console.error('❌ Error testing specific product:', error.message);
  }
}

testHoriishichimeienStock().catch(console.error);
