const axios = require('axios');
const cheerio = require('cheerio');

async function testSazenTea() {
  try {
    console.log('Testing Sazen Tea website...');
    
    const categoryUrl = 'https://www.sazentea.com/en/products/c21-matcha';
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
    
    // Test product selectors
    const productElements = $('.product');
    console.log(`Found ${productElements.length} products`);
    
    // Test first few products for image info
    productElements.slice(0, 3).each((i, el) => {
      const $el = $(el);
      const name = $el.find('.product-name').text().trim();
      const href = $el.find('a[href*="/products/"]').attr('href');
      
      console.log(`\\nProduct ${i + 1}: "${name}"`);
      console.log(`Link: ${href}`);
      
      // Check all images in this product
      const images = $el.find('img');
      console.log(`  Found ${images.length} images:`);
      
      images.each((j, img) => {
        const $img = $(img);
        const src = $img.attr('src') || $img.attr('data-src');
        const alt = $img.attr('alt') || '';
        const className = $img.attr('class') || '';
        const parentClass = $img.parent().attr('class') || '';
        
        console.log(`    Image ${j}: src="${src}", alt="${alt}", class="${className}", parentClass="${parentClass}"`);
        
        // Check if this is a tag/badge image
        if (alt.toLowerCase().includes('specialty') || 
            alt.toLowerCase().includes('extra flavorful') ||
            alt.toLowerCase().includes('tag') ||
            alt.toLowerCase().includes('badge') ||
            className.includes('tag') ||
            className.includes('badge') ||
            parentClass.includes('tag') ||
            parentClass.includes('badge')) {
          console.log(`      ^ This appears to be a tag/badge image`);
        }
      });
      
      // Try better image selectors
      const betterSelectors = [
        '.product-image img',
        '.product-photo img', 
        '.product-main-image img',
        'img[src*="product"]',
        'img:not([alt*="tag"]):not([alt*="badge"]):not([alt*="specialty"]):not([alt*="extra"])'
      ];
      
      for (const selector of betterSelectors) {
        const betterImg = $el.find(selector).first();
        if (betterImg.length > 0) {
          console.log(`  Better selector "${selector}": ${betterImg.attr('src')}`);
        }
      }
    });
    
  } catch (error) {
    console.error('Error testing Sazen Tea:', error.message);
  }
}

testSazenTea();
