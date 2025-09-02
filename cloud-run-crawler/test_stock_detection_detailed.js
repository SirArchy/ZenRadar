const axios = require('axios');
const cheerio = require('cheerio');

// Mock logger
const mockLogger = {
  info: (msg, data) => console.log(`INFO: ${msg}`, data),
  warn: (msg, data) => console.log(`WARN: ${msg}`, data),
  error: (msg, data) => console.log(`ERROR: ${msg}`, data)
};

const HoriishichimeienCrawler = require('./src/crawlers/horiishichimeien-crawler.js');

async function testStockDetection() {
  console.log('🔍 Testing Horiishichimeien stock detection in detail...');
  
  const crawler = new HoriishichimeienCrawler(mockLogger);
  
  try {
    // Fetch the page directly
    const response = await axios.get('https://horiishichimeien.com/en/collections/all?selected=%E6%8A%B9%E8%8C%B6', {
      timeout: 30000,
      headers: {
        'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache'
      }
    });
    
    const $ = cheerio.load(response.data);
    const productElements = $('.grid__item');
    
    console.log(`\n📦 Found ${productElements.length} product containers`);
    
    // Test first 3 products in detail
    for (let i = 0; i < Math.min(3, productElements.length); i++) {
      const productElement = $(productElements[i]);
      
      console.log(`\n🔍 Testing product ${i + 1}:`);
      
      // Get product name
      const nameSelectors = [
        'a[href*="/products/"] span.visually-hidden',
        '.card__heading',
        '.product-title',
        'a[href*="/products/"]'
      ];
      
      let name = '';
      for (const selector of nameSelectors) {
        const found = productElement.find(selector).first();
        if (found.length > 0) {
          const text = found.text().replace(/\n+/g, ' ').replace(/\s+/g, ' ').trim();
          if (text && text.length > 2) {
            name = text;
            break;
          }
        }
      }
      
      console.log(`  📝 Name: ${name}`);
      
      // Get product URL
      const linkElement = productElement.find('a[href*="/products/"]').first();
      let productUrl = '';
      
      if (linkElement.length > 0) {
        const href = linkElement.attr('href');
        productUrl = href.startsWith('http') ? href : 'https://horiishichimeien.com' + href;
      }
      
      console.log(`  🔗 URL: ${productUrl}`);
      
      // Analyze stock detection elements
      console.log(`  🛒 Stock Analysis:`);
      
      // Check element text for out of stock keywords
      const elementText = productElement.text().toLowerCase();
      const outOfStockKeywords = ['sold out', 'unavailable', '売り切れ', 'out of stock'];
      
      console.log(`    📄 Element text preview: "${elementText.substring(0, 200)}..."`);
      
      let foundOutOfStock = false;
      for (const keyword of outOfStockKeywords) {
        if (elementText.includes(keyword)) {
          console.log(`    ❌ Found out of stock keyword: "${keyword}"`);
          foundOutOfStock = true;
        }
      }
      
      if (!foundOutOfStock) {
        console.log(`    ✅ No out of stock keywords found`);
      }
      
      // Check for stock form elements
      const stockSelectors = [
        '.product-form__buttons',
        '.product-form',
        'form[action="/cart/add"]',
        'button[name="add"]'
      ];
      
      let foundStockForm = false;
      for (const selector of stockSelectors) {
        const elements = productElement.find(selector);
        if (elements.length > 0) {
          console.log(`    ✅ Found stock form element: "${selector}" (${elements.length} found)`);
          foundStockForm = true;
        }
      }
      
      if (!foundStockForm) {
        console.log(`    ❌ No stock form elements found`);
      }
      
      // Check for price elements
      const priceElements = productElement.find('.money, .price');
      console.log(`    💰 Price elements found: ${priceElements.length}`);
      
      // Final stock determination logic
      let isInStock;
      if (foundOutOfStock) {
        isInStock = false;
        console.log(`    🚫 Final result: OUT OF STOCK (found out of stock keywords)`);
      } else if (foundStockForm) {
        isInStock = true;
        console.log(`    ✅ Final result: IN STOCK (found stock form)`);
      } else {
        isInStock = priceElements.length > 0;
        console.log(`    ${isInStock ? '✅' : '❌'} Final result: ${isInStock ? 'IN STOCK' : 'OUT OF STOCK'} (default based on price presence)`);
      }
      
      // Let's also check what the raw HTML looks like for this product
      console.log(`    🔍 Raw HTML preview:`);
      console.log(`    ${productElement.html().substring(0, 500)}...`);
    }
    
  } catch (error) {
    console.error('❌ Error testing stock detection:', error.message);
  }
}

testStockDetection();
