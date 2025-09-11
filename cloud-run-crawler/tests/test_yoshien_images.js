const YoshienCrawler = require('../src/crawlers/yoshien-crawler.js');
const axios = require('axios');
const cheerio = require('cheerio');

const logger = { 
  info: (...args) => console.log('[INFO]', ...args), 
  warn: (...args) => console.warn('[WARN]', ...args), 
  error: (...args) => console.error('[ERROR]', ...args) 
};

async function testYoshienImages() {
  try {
    const crawler = new YoshienCrawler(logger);
    const config = crawler.getConfig();
    
    console.log('Testing Yoshien crawler...');
    console.log('Config:', JSON.stringify(config, null, 2));
    
    // First, let's fetch the page directly to see what we get
    console.log('\n--- Testing direct page fetch ---');
    const response = await axios.get(config.categoryUrl, {
      timeout: 30000,
      headers: {
        'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      }
    });
    
    const $ = cheerio.load(response.data);
    const productElements = $(config.productSelector);
    console.log(`Found ${productElements.length} product elements`);
    
    // Test image extraction on first few products
    for (let i = 0; i < Math.min(3, productElements.length); i++) {
      const productElement = $(productElements[i]);
      console.log(`\n--- Product ${i + 1} ---`);
      
      // Test name extraction
      const name = crawler.extractProductName(productElement);
      console.log('Name:', name);
      
      // Test image extraction - let's see what images we find
      const imageSelectors = [
        '.cs-product-tile__image img',
        '.product-image-photo',
        'img[src*="media/catalog/product"]',
        'a.product-item-link img',
        '.product-item-photo img',
        'img' // All images as fallback
      ];
      
      for (const selector of imageSelectors) {
        const imgs = productElement.find(selector);
        if (imgs.length > 0) {
          console.log(`Found ${imgs.length} images with selector "${selector}"`);
          imgs.each((idx, img) => {
            const $img = $(img);
            console.log(`  Image ${idx + 1}:`);
            console.log(`    src: ${$img.attr('src')}`);
            console.log(`    data-src: ${$img.attr('data-src')}`);
            console.log(`    data-original: ${$img.attr('data-original')}`);
            console.log(`    data-lazy: ${$img.attr('data-lazy')}`);
            console.log(`    data-srcset: ${$img.attr('data-srcset')}`);
          });
        }
      }
      
      // Test the actual image URL extraction
      const imageUrl = crawler.extractImageUrl(productElement, config);
      console.log('Extracted image URL:', imageUrl);
    }
    
    console.log('\n--- Running full crawler test ---');
    const result = await crawler.crawl(config.categoryUrl, config);
    console.log('Crawl result:', {
      productCount: result.products.length,
      products: result.products.slice(0, 3).map(p => ({
        name: p.name,
        price: p.price,
        imageUrl: p.imageUrl,
        url: p.url
      }))
    });
    
  } catch (error) {
    console.error('Test failed:', error.message);
    console.error('Stack:', error.stack);
  }
}

testYoshienImages();
