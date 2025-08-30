const axios = require('axios');
const cheerio = require('cheerio');

async function testMatchaKaru() {
  const config = {
    name: 'Matcha Kāru',
    baseUrl: 'https://matcha-karu.com',
    categoryUrl: 'https://matcha-karu.com/collections/matcha-tee',
    productSelector: '.product-item',
    nameSelector: 'h3, .product-title, [data-product-title], .product-item__title',
    priceSelector: '.price',
    stockSelector: '.add-to-cart, .cart-button',
    linkSelector: 'a',
    imageSelector: '.product-item__image img, .product-image img, img[src*="product"]',
    stockKeywords: ['add to cart', 'in den warenkorb', 'kaufen'],
    outOfStockKeywords: ['ausverkauft', 'nicht verfügbar', 'sold out']
  };

  try {
    console.log('Testing Matcha Kāru...');
    console.log('URL:', config.categoryUrl);

    const response = await axios.get(config.categoryUrl, {
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

    console.log('Response status:', response.status);
    console.log('Response length:', response.data.length);

    const $ = cheerio.load(response.data);

    // Test different product selectors
    const selectors = [
      '.product-item',
      '.product-card',
      '.grid-item',
      '.card',
      '[data-product-handle]',
      '.product-form',
      'article',
      '.product',
      '.item'
    ];

    console.log('\n=== Testing Product Selectors ===');
    for (const selector of selectors) {
      const elements = $(selector);
      console.log(`${selector}: ${elements.length} elements found`);
      
      if (elements.length > 0) {
        console.log('Sample element HTML (first 200 chars):');
        console.log($(elements[0]).html()?.substring(0, 200) + '...');
      }
    }

    // Check for specific Shopify patterns
    console.log('\n=== Shopify Patterns ===');
    const shopifySelectors = [
      '.grid__item',
      '.collection-product',
      '.product-card',
      '.product-item-container',
      '.card-wrapper',
      'product-card',
      '[data-product-id]'
    ];

    for (const selector of shopifySelectors) {
      const elements = $(selector);
      console.log(`${selector}: ${elements.length} elements found`);
    }

    // Look for product links
    console.log('\n=== Product Links ===');
    const productLinks = $('a[href*="/products/"]');
    console.log(`Product links found: ${productLinks.length}`);
    
    if (productLinks.length > 0) {
      console.log('Sample product links:');
      productLinks.each((i, el) => {
        if (i < 5) {
          const href = $(el).attr('href');
          const text = $(el).text().trim();
          console.log(`- ${href} (${text.substring(0, 50)}...)`);
        }
      });
    }

    // Check for German product names in page content
    console.log('\n=== German Matcha Products ===');
    const bodyText = $('body').text();
    const matchaMatches = bodyText.match(/Bio Matcha [A-Za-z]+/g);
    if (matchaMatches) {
      console.log('Found matcha products:');
      matchaMatches.slice(0, 10).forEach(match => console.log('- ' + match));
    }

    // Look for price elements
    console.log('\n=== Price Elements ===');
    const priceSelectors = [
      '.price',
      '.money',
      '.product-price',
      '.price-item',
      '[data-price]',
      '.price-regular',
      '.current-price'
    ];

    for (const selector of priceSelectors) {
      const elements = $(selector);
      console.log(`${selector}: ${elements.length} elements found`);
      if (elements.length > 0) {
        const samplePrice = $(elements[0]).text().trim();
        console.log(`  Sample: "${samplePrice}"`);
      }
    }

  } catch (error) {
    console.error('Error testing Matcha Kāru:', error.message);
  }
}

testMatchaKaru();
