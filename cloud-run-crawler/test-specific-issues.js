const axios = require('axios');
const cheerio = require('cheerio');

class TestCrawler {
  constructor() {
    this.userAgent = 'ZenRadar Bot 1.0 (+https://zenradar.app)';
    this.requestConfig = {
      timeout: 30000,
      headers: {
        'User-Agent': this.userAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,de;q=0.8,sv;q=0.7',
        'Accept-Encoding': 'gzip, deflate, br',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
      }
    };
  }

  async testPoppateaImages() {
    console.log('🍵 Testing Poppatea image extraction...');
    
    try {
      const response = await axios.get('https://poppatea.com/collections/all', this.requestConfig);
      const $ = cheerio.load(response.data);
      
      const products = $('.card, .product-card, .grid-item').slice(0, 3);
      console.log(`Found ${products.length} products to test`);
      
      products.each((index, element) => {
        const $el = $(element);
        const name = $el.find('h3, .card-title, [data-product-title], .product-title').text().trim();
        
        // Test multiple image selectors
        const imageSelectors = [
          '.card-image img',
          '.product-image img', 
          'img[src*="product"]',
          'img',
          '.image img',
          '.card__media img'
        ];
        
        console.log(`\nProduct ${index + 1}: ${name}`);
        
        for (const selector of imageSelectors) {
          const img = $el.find(selector).first();
          if (img.length) {
            const src = img.attr('src') || img.attr('data-src') || img.attr('data-original');
            console.log(`  ${selector}: ${src}`);
          } else {
            console.log(`  ${selector}: NOT FOUND`);
          }
        }
        
        // Check all img elements in this product
        const allImages = $el.find('img');
        console.log(`  Total img elements: ${allImages.length}`);
        allImages.each((i, img) => {
          const $img = $(img);
          console.log(`    img[${i}]: src="${$img.attr('src')}" data-src="${$img.attr('data-src')}" alt="${$img.attr('alt')}"`);
        });
      });
      
    } catch (error) {
      console.error('❌ Error testing Poppatea images:', error.message);
    }
  }

  async testShoChaImages() {
    console.log('\n🍃 Testing Sho-Cha image extraction...');
    
    try {
      const response = await axios.get('https://www.sho-cha.com/teeshop', this.requestConfig);
      const $ = cheerio.load(response.data);
      
      const products = $('h1').slice(0, 3);
      console.log(`Found ${products.length} h1 elements to test`);
      
      products.each((index, element) => {
        const $el = $(element);
        const name = $el.text().trim();
        
        if (name && name.toLowerCase().includes('matcha')) {
          console.log(`\nProduct ${index + 1}: ${name}`);
          
          // Look for images in the same container or nearby
          const container = $el.closest('div, section, article');
          const imageSelectors = [
            '.product-image img',
            '.item-image img', 
            'img[src*="product"]',
            'img[src*="tea"]',
            'img[src*="matcha"]',
            'img'
          ];
          
          for (const selector of imageSelectors) {
            const img = container.find(selector).first();
            if (img.length) {
              const src = img.attr('src') || img.attr('data-src') || img.attr('data-original');
              console.log(`  ${selector}: ${src}`);
            } else {
              console.log(`  ${selector}: NOT FOUND`);
            }
          }
        }
      });
      
    } catch (error) {
      console.error('❌ Error testing Sho-Cha images:', error.message);
    }
  }

  async testHoriishichimeienStock() {
    console.log('\n🏯 Testing Horiishichimeien stock tracking...');
    
    try {
      const response = await axios.get('https://horiishichimeien.com/en/collections/all?selected=%E6%8A%B9%E8%8C%B6', this.requestConfig);
      const $ = cheerio.load(response.data);
      
      const products = $('.grid__item').slice(0, 5);
      console.log(`Found ${products.length} products to test`);
      
      products.each((index, element) => {
        const $el = $(element);
        const name = $el.find('a[href*="/products/"] span.visually-hidden, .card__heading, .product-title').text().trim();
        
        console.log(`\nProduct ${index + 1}: ${name}`);
        
        // Test stock selectors
        const stockSelectors = [
          '.product-form__buttons',
          '.product-form',
          'form[action="/cart/add"]',
          'button[name="add"]',
          '.btn--add-to-cart',
          'button:contains("Add")',
          'button:contains("cart")',
          'button:contains("カート")'
        ];
        
        for (const selector of stockSelectors) {
          const stock = $el.find(selector);
          console.log(`  ${selector}: ${stock.length > 0 ? 'FOUND' : 'NOT FOUND'}`);
          if (stock.length > 0) {
            console.log(`    Text: "${stock.text().trim()}"`);
            console.log(`    Disabled: ${stock.attr('disabled') ? 'YES' : 'NO'}`);
          }
        }
        
        // Check for out of stock indicators
        const outOfStockSelectors = [
          ':contains("sold out")',
          ':contains("売り切れ")',
          ':contains("out of stock")',
          ':contains("unavailable")',
          '.sold-out',
          '.out-of-stock'
        ];
        
        for (const selector of outOfStockSelectors) {
          const outOfStock = $el.find(selector);
          if (outOfStock.length > 0) {
            console.log(`  OUT OF STOCK: ${selector} - "${outOfStock.text().trim()}"`);
          }
        }
      });
      
    } catch (error) {
      console.error('❌ Error testing Horiishichimeien stock:', error.message);
    }
  }

  async testPoppateaVariants() {
    console.log('\n🛒 Testing Poppatea variant extraction...');
    
    try {
      // Test a specific product page
      const testUrl = 'https://poppatea.com/de-de/products/matcha-tea-ceremonial';
      const response = await axios.get(testUrl, this.requestConfig);
      const $ = cheerio.load(response.data);
      
      console.log(`Testing product page: ${testUrl}`);
      
      // Look for Shopify product JSON
      const scriptTags = $('script[type="application/json"], script:contains("variants"), script:contains("product")');
      console.log(`Found ${scriptTags.length} script tags to check`);
      
      let foundVariants = false;
      scriptTags.each((index, script) => {
        const scriptContent = $(script).html();
        
        if (scriptContent && scriptContent.includes('variants')) {
          console.log(`\nScript ${index + 1} contains variants:`);
          console.log(scriptContent.substring(0, 200) + '...');
          
          try {
            const jsonData = JSON.parse(scriptContent);
            if (jsonData.variants) {
              console.log(`Found ${jsonData.variants.length} variants in JSON`);
              jsonData.variants.forEach((variant, i) => {
                console.log(`  Variant ${i + 1}: ${variant.title} - €${(variant.price / 100).toFixed(2)} - Available: ${variant.available}`);
              });
              foundVariants = true;
            }
          } catch (e) {
            console.log('  Not valid JSON or different structure');
          }
        }
      });
      
      if (!foundVariants) {
        console.log('No variants found in JSON, checking HTML selectors...');
        
        const variantSelectors = $('select[name="id"], .product-form__option select, input[name="id"]');
        console.log(`Found ${variantSelectors.length} variant selectors`);
        
        variantSelectors.each((index, element) => {
          const $element = $(element);
          console.log(`\nSelector ${index + 1}:`);
          
          if ($element.is('select')) {
            $element.find('option').each((i, option) => {
              const $option = $(option);
              console.log(`  Option: "${$option.text().trim()}" (value: ${$option.attr('value')})`);
            });
          }
        });
      }
      
    } catch (error) {
      console.error('❌ Error testing Poppatea variants:', error.message);
    }
  }
}

async function runTests() {
  const tester = new TestCrawler();
  
  await tester.testPoppateaImages();
  await tester.testShoChaImages();
  await tester.testHoriishichimeienStock();
  await tester.testPoppateaVariants();
  
  console.log('\n✅ Tests completed');
}

runTests().catch(console.error);
