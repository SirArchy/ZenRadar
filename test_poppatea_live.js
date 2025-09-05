const axios = require('axios');
const cheerio = require('cheerio');

async function testPoppateaWebsite() {
  console.log('Testing Poppatea website crawling...');
  
  try {
    const response = await axios.get('https://poppatea.com/de-de/collections/all-teas', {
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
    
    console.log(`✅ Successfully fetched Poppatea page (${response.status})`);
    
    const $ = cheerio.load(response.data);
    
    // Test different selectors
    console.log('\n🔍 Testing different selectors:');
    
    const cardSelector = $('.card');
    console.log(`📦 .card elements: ${cardSelector.length}`);
    
    const productCardSelector = $('.product-card');
    console.log(`📦 .product-card elements: ${productCardSelector.length}`);
    
    const gridItemSelector = $('.grid-item');
    console.log(`📦 .grid-item elements: ${gridItemSelector.length}`);
    
    // Look for cards with titles (as used in crawler)
    const cardsWithTitles = $('.card').filter((i, el) => {
      const title = $(el).find('h3, .card-title, [data-product-title], .product-title').text().trim();
      return title.length > 0;
    });
    
    console.log(`📦 .card elements with titles: ${cardsWithTitles.length}`);
    
    // Check what's in these cards
    console.log('\n📋 Found products:');
    cardsWithTitles.each((index, card) => {
      const $card = $(card);
      
      const titleElement = $card.find('h3, .card-title, [data-product-title], .product-title').first();
      const title = titleElement.text().trim();
      
      const priceElement = $card.find('.price, .money').first();
      const price = priceElement.text().trim();
      
      const linkElement = $card.find('a').first();
      const link = linkElement.attr('href');
      
      console.log(`${index + 1}. Title: "${title}"`);
      console.log(`   Price: "${price}"`);
      console.log(`   Link: "${link}"`);
      console.log('');
    });
    
    // Also check if there are any other product containers
    console.log('\n🔍 Looking for other product containers:');
    const allLinks = $('a[href*="/products/"]');
    console.log(`🔗 Product links found: ${allLinks.length}`);
    
    const uniqueProducts = new Set();
    allLinks.each((index, link) => {
      const href = $(link).attr('href');
      if (href && href.includes('/products/')) {
        uniqueProducts.add(href);
      }
    });
    
    console.log(`🔗 Unique product URLs: ${uniqueProducts.size}`);
    
    // List first few unique products
    const productUrls = Array.from(uniqueProducts).slice(0, 10);
    productUrls.forEach((url, index) => {
      console.log(`${index + 1}. ${url}`);
    });
    
  } catch (error) {
    console.error('❌ Error testing Poppatea website:', error.message);
    if (error.response) {
      console.error('Response status:', error.response.status);
      console.error('Response headers:', error.response.headers);
    }
  }
}

testPoppateaWebsite();
