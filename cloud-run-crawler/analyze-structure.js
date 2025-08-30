const axios = require('axios');
const cheerio = require('cheerio');

async function analyzePageStructure() {
  console.log('🔍 Analyzing Page Structure for Better Selectors\n');
  
  const sites = [
    {
      name: 'Matcha-Kāru',
      url: 'https://matcha-karu.com/collections/all'
    },
    {
      name: 'Poppatea',
      url: 'https://poppatea.com/collections/all'
    }
  ];
  
  for (const site of sites) {
    console.log(`\n🧪 Analyzing ${site.name}:`);
    
    try {
      const response = await axios.get(site.url, {
        timeout: 10000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
      });
      
      const $ = cheerio.load(response.data);
      
      console.log(`📊 Content Length: ${response.data.length} characters`);
      
      // Look for common product selectors
      const potentialSelectors = [
        '.product',
        '.product-card',
        '.product-item',
        '.grid-item',
        '.grid__item',
        '.product-tile',
        '.collection-item',
        '[data-product]',
        '.card',
        '.item'
      ];
      
      console.log('\n📝 Testing Product Selectors:');
      for (const selector of potentialSelectors) {
        const count = $(selector).length;
        if (count > 0) {
          console.log(`   ${selector}: ${count} elements`);
          
          // Sample the first element
          const firstElement = $(selector).first();
          const text = firstElement.text().trim().substring(0, 100);
          if (text && text.toLowerCase().includes('matcha')) {
            console.log(`      🎯 Contains "matcha": ${text}...`);
          }
        }
      }
      
      // Look for price patterns
      console.log('\n💰 Looking for price patterns:');
      const priceSelectors = ['.price', '.money', '.cost', '.amount', '$'];
      for (const selector of priceSelectors) {
        const elements = $(selector);
        if (elements.length > 0) {
          console.log(`   ${selector}: ${elements.length} elements`);
          const sampleText = elements.first().text().trim();
          if (sampleText) {
            console.log(`      Sample: ${sampleText}`);
          }
        }
      }
      
      // Check if it might be using a different page structure
      console.log('\n🔍 Page title and main structure:');
      console.log(`   Title: ${$('title').text()}`);
      console.log(`   Main containers: ${$('main, .main, #main').length}`);
      console.log(`   Collections: ${$('[class*="collection"], [id*="collection"]').length}`);
      
    } catch (error) {
      console.log(`❌ Error: ${error.message}`);
    }
  }
}

analyzePageStructure().catch(console.error);
