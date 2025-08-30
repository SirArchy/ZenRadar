const axios = require('axios');
const cheerio = require('cheerio');

async function testHoriishichimeien() {
  console.log('=== Testing Horiishichimeien Issues ===');
  
  // Test the problematic image URL
  const imageUrl = 'https://horiishichimeien.com/cdn/shop/products/MG_8632_{width}x.jpg';
  console.log('Testing image URL:', imageUrl);
  
  try {
    const response = await axios.get(imageUrl, { timeout: 10000 });
    console.log('Image URL works:', response.status);
  } catch (error) {
    console.log('Image URL failed:', error.response?.status || error.code);
    
    // Try without the {width}x template
    const fixedUrl = imageUrl.replace('_{width}x', '');
    console.log('Trying fixed URL:', fixedUrl);
    
    try {
      const fixedResponse = await axios.get(fixedUrl, { timeout: 10000 });
      console.log('Fixed image URL works:', fixedResponse.status);
    } catch (fixedError) {
      console.log('Fixed image URL also failed:', fixedError.response?.status || fixedError.code);
    }
  }
  
  // Test a specific product page to understand the price structure
  const productUrl = 'https://horiishichimeien.com/en/products/hojicha-agatanokaori';
  console.log('\nTesting product page:', productUrl);
  
  try {
    const response = await axios.get(productUrl, {
      timeout: 30000,
      headers: {
        'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      }
    });
    
    console.log('Product page status:', response.status);
    
    const $ = cheerio.load(response.data);
    
    // Look for price elements
    console.log('\n=== Price Analysis ===');
    const priceSelectors = [
      '.price',
      '.money',
      '.price__regular',
      '.price-item--regular',
      '.product-price',
      '[data-price]',
      '.current-price',
      '.regular-price'
    ];
    
    for (const selector of priceSelectors) {
      const elements = $(selector);
      if (elements.length > 0) {
        console.log(`${selector}: ${elements.length} found`);
        elements.each((i, el) => {
          if (i < 3) {
            const text = $(el).text().trim();
            const html = $(el).html();
            console.log(`  [${i}] Text: "${text}"`);
            console.log(`      HTML: "${html?.substring(0, 100)}..."`);
          }
        });
      }
    }
    
    // Look for JSON data that might contain prices
    console.log('\n=== JSON Price Data ===');
    const scripts = $('script');
    scripts.each((i, script) => {
      const content = $(script).html();
      if (content && (content.includes('price') || content.includes('¥') || content.includes('648'))) {
        console.log(`Script ${i} contains price data:`);
        console.log(content.substring(0, 500) + '...');
      }
    });
    
    // Check the page text for ¥648
    const bodyText = $('body').text();
    if (bodyText.includes('648')) {
      console.log('\nFound "648" in page text');
      const context = bodyText.match(/.{0,50}648.{0,50}/g);
      if (context) {
        console.log('Price context:', context);
      }
    }
    
  } catch (error) {
    console.error('Error testing Horiishichimeien product:', error.message);
  }
}

testHoriishichimeien();
