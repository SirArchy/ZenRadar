const axios = require('axios');
const cheerio = require('cheerio');

async function analyzePoppateaStructure() {
  console.log('🔍 Analyzing Poppatea Website Structure\n');
  
  // Test multiple potential URLs
  const testUrls = [
    'https://poppatea.se/collections/matcha',
    'https://poppatea.se/collections/all',
    'https://poppatea.se',
    'https://www.poppatea.se',
    'https://www.poppatea.se/collections/matcha'
  ];

  for (const url of testUrls) {
    console.log(`\n🌐 Testing URL: ${url}`);
    
    try {
      const response = await axios.get(url, {
        timeout: 15000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
        }
      });
      
      console.log(`✅ Success! Status: ${response.status}`);
      console.log(`📄 Content length: ${response.data.length} characters`);
      
      const $ = cheerio.load(response.data);
      
      // Analyze page structure
      console.log('\n📊 Page Analysis:');
      console.log(`Title: ${$('title').text().trim()}`);
      console.log(`Meta description: ${$('meta[name="description"]').attr('content') || 'Not found'}`);
      
      // Look for product containers with various selectors
      const productSelectors = [
        '.product-item',
        '.product-card',
        '.grid-item',
        '.product',
        '[data-product]',
        '.collection-product',
        '.product-grid-item',
        '.card-product',
        '.product-block'
      ];
      
      console.log('\n🔍 Product Container Analysis:');
      for (const selector of productSelectors) {
        const elements = $(selector);
        if (elements.length > 0) {
          console.log(`✅ ${selector}: ${elements.length} elements found`);
          
          // Analyze first element structure
          const firstElement = elements.first();
          console.log(`   Sample HTML structure (first 200 chars):`);
          console.log(`   ${firstElement.html().substring(0, 200)}...`);
          
          // Look for product links and names
          const links = firstElement.find('a[href*="product"]');
          const titles = firstElement.find('h1, h2, h3, h4, .title, .name, .product-title');
          const prices = firstElement.find('.price, .cost, .amount, [class*="price"]');
          
          console.log(`   - Links found: ${links.length}`);
          console.log(`   - Title elements: ${titles.length}`);
          console.log(`   - Price elements: ${prices.length}`);
          
          if (links.length > 0) {
            console.log(`   - Sample link: ${links.first().attr('href')}`);
          }
          if (titles.length > 0) {
            console.log(`   - Sample title: ${titles.first().text().trim()}`);
          }
          if (prices.length > 0) {
            console.log(`   - Sample price: ${prices.first().text().trim()}`);
          }
        } else {
          console.log(`❌ ${selector}: No elements found`);
        }
      }
      
      // Look for Shopify indicators
      console.log('\n🛍️ E-commerce Platform Detection:');
      if (response.data.includes('Shopify')) {
        console.log('✅ Shopify platform detected');
      }
      if (response.data.includes('product-form')) {
        console.log('✅ Product forms detected');
      }
      if (response.data.includes('collection')) {
        console.log('✅ Collection pages detected');
      }
      
      // Check for matcha products specifically
      console.log('\n🍵 Matcha Product Detection:');
      const matchaText = response.data.toLowerCase();
      const matchaCount = (matchaText.match(/matcha/g) || []).length;
      console.log(`Matcha mentions: ${matchaCount}`);
      
      if (matchaCount > 0) {
        console.log('✅ Matcha products likely present');
      }
      
      // Success - we found a working URL
      console.log(`\n🎯 WORKING URL FOUND: ${url}`);
      break;
      
    } catch (error) {
      console.log(`❌ Failed: ${error.message}`);
      
      if (error.code === 'ENOTFOUND') {
        console.log('🚫 Domain not found - trying next URL...');
      } else if (error.response) {
        console.log(`📄 HTTP ${error.response.status}: ${error.response.statusText}`);
      } else if (error.code === 'ECONNREFUSED') {
        console.log('🔒 Connection refused - server may be down');
      } else if (error.code === 'ETIMEDOUT') {
        console.log('⏱️ Request timeout - server may be slow');
      }
    }
  }
  
  console.log('\n✨ Analysis Complete!');
}

if (require.main === module) {
  analyzePoppateaStructure().catch(console.error);
}

module.exports = { analyzePoppateaStructure };
