const axios = require('axios');
const cheerio = require('cheerio');

async function testHoriishichimeien() {
  try {
    console.log('Testing Horiishichimeien website...');
    
    const categoryUrl = 'https://horiishichimeien.com/en/collections/all?selected=%E6%8A%B9%E8%8C%B6';
    console.log('Fetching:', categoryUrl);
    
    const response = await axios.get(categoryUrl, {
      timeout: 30000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      }
    });
    
    console.log('Response status:', response.status);
    console.log('Response length:', response.data.length);
    
    const $ = cheerio.load(response.data);
    
    // Test different selectors
    const selectors = [
      '.grid__item .card',
      '.grid-product__link', 
      'a[href*="/products/matcha-"]',
      '.grid__item',
      '.card',
      '.product-item',
      'a[href*="/products/"]'
    ];
    
    for (const selector of selectors) {
      const elements = $(selector);
      console.log(`Selector "${selector}": found ${elements.length} elements`);
      
      if (elements.length > 0) {
        // Show first few matches
        elements.slice(0, 3).each((i, el) => {
          const $el = $(el);
          const href = $el.attr('href') || $el.find('a').attr('href');
          const text = $el.text().trim().substring(0, 100);
          console.log(`  [${i}] href: ${href}, text: "${text}"`);
        });
      }
    }
    
    // Check for any products/links
    const allLinks = $('a[href*="/products/"]');
    console.log('\nAll product links found:', allLinks.length);
    
    if (allLinks.length === 0) {
      console.log('\nHTML preview (first 1000 chars):');
      console.log(response.data.substring(0, 1000));
    }
    
  } catch (error) {
    console.error('Error testing Horiishichimeien:', error.message);
  }
}

testHoriishichimeien();
