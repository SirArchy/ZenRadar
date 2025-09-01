const axios = require('axios');
const cheerio = require('cheerio');

/**
 * Test script to debug Horiishichimeien price conversion
 */
async function testHoriishichimeienPriceConversion() {
  console.log('🔍 Testing Horiishichimeien Price Conversion');
  console.log('===========================================\n');

  // Test the current exchange rate calculation
  const testPrice = 648; // JPY
  const currentRate = 0.0067;
  const currentConversion = testPrice * currentRate;
  
  console.log(`💴 Original price: ¥${testPrice}`);
  console.log(`📊 Current rate: ${currentRate} EUR per JPY`);
  console.log(`💰 Current conversion: €${currentConversion.toFixed(2)}`);
  console.log(`🎯 Expected conversion: €3.76`);
  
  const correctRate = 3.76 / 648;
  console.log(`✅ Correct rate should be: ${correctRate.toFixed(6)} EUR per JPY`);
  
  console.log('\n' + '='.repeat(50));
  
  // Test actual website crawling
  try {
    const response = await axios.get('https://horiishichimeien.com/en/collections/all?selected=%E6%8A%B9%E8%8C%B6', {
      timeout: 30000,
      headers: {
        'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
      }
    });
    
    const $ = cheerio.load(response.data);
    const productElements = $('.grid__item');
    
    console.log(`🔍 Found ${productElements.length} product containers on Horiishichimeien`);
    
    // Look for the specific product
    let foundHojichaAgata = false;
    
    for (let i = 0; i < Math.min(productElements.length, 10); i++) {
      const productElement = $(productElements[i]);
      
      // Try to find product name
      const nameElement = productElement.find('a[href*="/products/"] span.visually-hidden, .card__heading, .product-title').first();
      const name = nameElement.text().trim();
      
      // Try to find price
      const priceElement = productElement.find('.price__regular .money, .price .money, .price-item--regular').first();
      const rawPrice = priceElement.text().trim();
      
      if (name.toLowerCase().includes('hojicha') && name.toLowerCase().includes('agata')) {
        foundHojichaAgata = true;
        console.log(`\n✨ Found Hojicha Agata product:`);
        console.log(`📝 Name: ${name}`);
        console.log(`💴 Raw price: "${rawPrice}"`);
        
        // Test price extraction patterns
        const patterns = [
          /¥(\d{1,3}(?:,\d{3})*)/,
          /¥(\d+)/,
          /(\d{1,3}(?:,\d{3})*)/,
          /(\d+)/
        ];
        
        for (const pattern of patterns) {
          const match = rawPrice.match(pattern);
          if (match) {
            const extractedValue = match[1].replace(/,/g, '');
            const numericValue = parseFloat(extractedValue);
            console.log(`🔍 Pattern ${pattern} extracted: ${extractedValue} (${numericValue})`);
            
            // Test conversion with different rates
            const withCurrentRate = numericValue * currentRate;
            const withCorrectRate = numericValue * correctRate;
            console.log(`💰 With current rate (${currentRate}): €${withCurrentRate.toFixed(2)}`);
            console.log(`✅ With correct rate (${correctRate.toFixed(6)}): €${withCorrectRate.toFixed(2)}`);
          }
        }
      } else if (name && rawPrice) {
        console.log(`\n📦 Product ${i + 1}:`);
        console.log(`📝 Name: ${name.substring(0, 50)}${name.length > 50 ? '...' : ''}`);
        console.log(`💴 Raw price: "${rawPrice}"`);
        
        // Test price extraction
        const yenMatch = rawPrice.match(/¥(\d+(?:,\d{3})*)/);
        if (yenMatch) {
          const jpyValue = parseFloat(yenMatch[1].replace(/,/g, ''));
          const converted = jpyValue * correctRate;
          console.log(`💰 Extracted: ¥${jpyValue} → €${converted.toFixed(2)}`);
        }
      }
    }
    
    if (!foundHojichaAgata) {
      console.log('\n⚠️ Hojicha Agata no Kaori product not found in first 10 products');
      console.log('📋 Available products:');
      for (let i = 0; i < Math.min(productElements.length, 5); i++) {
        const productElement = $(productElements[i]);
        const nameElement = productElement.find('a[href*="/products/"] span.visually-hidden, .card__heading, .product-title').first();
        const name = nameElement.text().trim();
        if (name) {
          console.log(`   ${i + 1}. ${name.substring(0, 60)}`);
        }
      }
    }
    
  } catch (error) {
    console.error('❌ Failed to test Horiishichimeien crawling:', error.message);
  }
}

// Run the test
if (require.main === module) {
  testHoriishichimeienPriceConversion().catch(console.error);
}

module.exports = { testHoriishichimeienPriceConversion };
