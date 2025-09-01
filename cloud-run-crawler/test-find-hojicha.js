const axios = require('axios');
const cheerio = require('cheerio');

/**
 * Extended test to find the Hojicha Agata no Kaori product
 */
async function findHojichaProduct() {
  console.log('🔍 Searching for Hojicha Agata no Kaori product');
  console.log('==============================================\n');

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
    
    console.log(`🔍 Searching through ${productElements.length} products...\n`);
    
    let found = false;
    
    for (let i = 0; i < productElements.length; i++) {
      const productElement = $(productElements[i]);
      
      // Try multiple name selectors
      const nameSelectors = [
        'a[href*="/products/"] span.visually-hidden',
        '.card__heading',
        '.product-title',
        'a[href*="/products/"]',
        '.card-title',
        'h3'
      ];
      
      let name = '';
      for (const selector of nameSelectors) {
        const element = productElement.find(selector).first();
        if (element.length > 0) {
          name = element.text().trim();
          if (name && name.length > 3) break;
        }
      }
      
      // Check if this is a Hojicha product
      if (name.toLowerCase().includes('hojicha')) {
        found = true;
        console.log(`🍃 Found Hojicha product #${i + 1}:`);
        console.log(`📝 Name: "${name}"`);
        
        // Try multiple price selectors
        const priceSelectors = [
          '.price__regular .money',
          '.price .money',
          '.price-item--regular',
          '.money',
          '.price',
          '[data-price]'
        ];
        
        let rawPrice = '';
        for (const selector of priceSelectors) {
          const element = productElement.find(selector).first();
          if (element.length > 0) {
            rawPrice = element.text().trim();
            if (rawPrice) {
              console.log(`💴 Price (${selector}): "${rawPrice}"`);
            }
          }
        }
        
        // Also check for Shopify product data
        const productLink = productElement.find('a[href*="/products/"]').first();
        if (productLink.length > 0) {
          const href = productLink.attr('href');
          console.log(`🔗 Product URL: ${href}`);
          
          // If this is Agata no Kaori, let's investigate further
          if (name.toLowerCase().includes('agata')) {
            console.log(`🎯 This might be the target product!`);
            
            // Try to extract price using different methods
            const allText = productElement.text();
            console.log(`📄 Full element text: "${allText.replace(/\s+/g, ' ').trim()}"`);
            
            // Look for price patterns in the full text
            const pricePatterns = [
              /¥(\d{1,3}(?:,\d{3})*)/g,
              /¥(\d+)/g,
              /(\d{1,3}(?:,\d{3})*)\s*JPY/g,
              /(\d+)\s*JPY/g
            ];
            
            for (const pattern of pricePatterns) {
              let match;
              while ((match = pattern.exec(allText)) !== null) {
                const extractedPrice = match[1].replace(/,/g, '');
                console.log(`💰 Price pattern ${pattern} found: ¥${extractedPrice}`);
                
                // Test different conversion scenarios
                if (extractedPrice === '648') {
                  console.log(`🔥 Found ¥648! Testing conversions:`);
                  console.log(`   Current rate (0.0067): €${(648 * 0.0067).toFixed(2)}`);
                  console.log(`   Correct rate (0.005802): €${(648 * 0.005802).toFixed(2)}`);
                  console.log(`   If price was in cents: €${(6.48 * 0.0067).toFixed(2)}`);
                  console.log(`   If price was divided by 100: €${(648 / 100).toFixed(2)}`);
                }
              }
            }
          }
        }
        
        console.log(''); // Empty line for separation
      }
    }
    
    if (!found) {
      console.log('❌ No Hojicha products found');
      
      // Let's try searching for "agata" specifically
      console.log('\n🔍 Searching for any products containing "agata"...');
      for (let i = 0; i < productElements.length; i++) {
        const productElement = $(productElements[i]);
        const fullText = productElement.text().toLowerCase();
        
        if (fullText.includes('agata')) {
          const nameElement = productElement.find('a[href*="/products/"] span.visually-hidden, .card__heading, .product-title').first();
          const name = nameElement.text().trim();
          console.log(`📦 Found "agata" in product: "${name}"`);
        }
      }
    }
    
  } catch (error) {
    console.error('❌ Failed to search for Hojicha product:', error.message);
  }
}

// Run the search
if (require.main === module) {
  findHojichaProduct().catch(console.error);
}

module.exports = { findHojichaProduct };
