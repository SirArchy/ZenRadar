const axios = require('axios');
const cheerio = require('cheerio');

async function testShoCha() {
  const config = {
    name: 'Sho-Cha',
    baseUrl: 'https://www.sho-cha.com',
    categoryUrl: 'https://www.sho-cha.com/teeshop',
    productSelector: '.product-item, .product, .item',
    nameSelector: '.product-title, .item-title, h3, h4',
    priceSelector: '.price, .cost, .amount',
    stockSelector: '.add-to-cart, .cart-button',
    linkSelector: 'a',
    imageSelector: '.product-image img, .item-image img, img[src*="product"], img[src*="tea"]',
    stockKeywords: ['add to cart', 'kaufen', 'in den warenkorb'],
    outOfStockKeywords: ['ausverkauft', 'sold out', 'nicht verfügbar']
  };

  try {
    console.log('Testing Sho-Cha...');
    console.log('URL:', config.categoryUrl);

    const response = await axios.get(config.categoryUrl, {
      timeout: 30000,
      headers: {
        'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5,de;q=0.3',
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
      '.product',
      '.item',
      '.product-card',
      '.tea-product',
      '.shop-item',
      'article',
      '.content-item',
      '.grid-item',
      '.card'
    ];

    console.log('\n=== Testing Product Selectors ===');
    for (const selector of selectors) {
      const elements = $(selector);
      console.log(`${selector}: ${elements.length} elements found`);
      
      if (elements.length > 0) {
        console.log('Sample element HTML (first 300 chars):');
        console.log($(elements[0]).html()?.substring(0, 300) + '...');
      }
    }

    // Look for any elements with text containing "tee", "tea", "matcha"
    console.log('\n=== Tea-related Content ===');
    const bodyText = $('body').text().toLowerCase();
    console.log('Page contains "matcha":', bodyText.includes('matcha'));
    console.log('Page contains "tee":', bodyText.includes('tee'));
    console.log('Page contains "tea":', bodyText.includes('tea'));

    // Look for product links
    console.log('\n=== Links Analysis ===');
    const allLinks = $('a[href]');
    console.log(`Total links found: ${allLinks.length}`);
    
    const productLinks = $('a[href*="product"], a[href*="tea"], a[href*="matcha"]');
    console.log(`Product-like links: ${productLinks.length}`);
    
    if (productLinks.length > 0) {
      console.log('Sample product links:');
      productLinks.each((i, el) => {
        if (i < 10) {
          const href = $(el).attr('href');
          const text = $(el).text().trim();
          console.log(`- ${href} (${text.substring(0, 50)}...)`);
        }
      });
    }

    // Check for forms or interactive elements
    console.log('\n=== Interactive Elements ===');
    const forms = $('form');
    const buttons = $('button');
    const inputs = $('input[type="submit"], input[type="button"]');
    
    console.log(`Forms: ${forms.length}`);
    console.log(`Buttons: ${buttons.length}`);
    console.log(`Submit inputs: ${inputs.length}`);

    // Look for price-like patterns in text
    console.log('\n=== Price Patterns ===');
    const priceRegex = /€\s*\d+[.,]?\d*/g;
    const priceMatches = bodyText.match(priceRegex);
    if (priceMatches) {
      console.log('Found price patterns:');
      [...new Set(priceMatches)].slice(0, 10).forEach(price => console.log('- ' + price));
    }

    // Check if this might be a different type of site structure
    console.log('\n=== Page Structure Analysis ===');
    const title = $('title').text();
    const h1s = $('h1').map((i, el) => $(el).text().trim()).get();
    const h2s = $('h2').map((i, el) => $(el).text().trim()).get();
    
    console.log('Page title:', title);
    console.log('H1 elements:', h1s.slice(0, 5));
    console.log('H2 elements:', h2s.slice(0, 5));

    // Look for navigation or menu items
    console.log('\n=== Navigation Analysis ===');
    const navItems = $('nav a, .menu a, .navigation a').map((i, el) => $(el).text().trim()).get();
    console.log('Navigation items:', navItems.slice(0, 10));

  } catch (error) {
    console.error('Error testing Sho-Cha:', error.message);
    console.error('Stack:', error.stack);
  }
}

testShoCha();
