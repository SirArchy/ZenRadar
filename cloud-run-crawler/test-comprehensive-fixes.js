const axios = require('axios');
const cheerio = require('cheerio');

class ComprehensiveTestCrawler {
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

  async testPoppateaEnhanced() {
    console.log('🛒 Testing Enhanced Poppatea Crawling...');
    
    try {
      const response = await axios.get('https://poppatea.com/collections/all', this.requestConfig);
      const $ = cheerio.load(response.data);
      
      const products = $('.card, .product-card, .grid-item').slice(0, 2);
      console.log(`Found ${products.length} products to analyze`);
      
      for (let i = 0; i < products.length; i++) {
        const $el = $(products[i]);
        const name = $el.find('h3, .card-title, [data-product-title], .product-title').text().trim();
        const link = $el.find('a').first().attr('href');
        
        console.log(`\n--- Product ${i + 1}: ${name} ---`);
        
        // Test enhanced image selector
        const img = $el.find('img, .card-image img, .product-image img, img[src*="product"], img[src*="cdn/shop"]').first();
        const imgSrc = img.attr('src') || img.attr('data-src');
        console.log(`Image: ${imgSrc ? imgSrc.substring(0, 80) + '...' : 'NOT FOUND'}`);
        
        if (link && !link.startsWith('http')) {
          const productUrl = 'https://poppatea.com' + link;
          console.log(`Product URL: ${productUrl}`);
          
          // Test variant extraction from product page
          await this.testProductPageVariants(productUrl);
        }
      }
      
    } catch (error) {
      console.error('❌ Error testing enhanced Poppatea:', error.message);
    }
  }

  async testProductPageVariants(productUrl) {
    try {
      console.log(`  Testing variants for: ${productUrl}`);
      const response = await axios.get(productUrl, this.requestConfig);
      const $ = cheerio.load(response.data);
      
      // Test ShopifyAnalytics detection
      const shopifyAnalyticsScript = $('script:contains("window.ShopifyAnalytics")').html();
      if (shopifyAnalyticsScript && shopifyAnalyticsScript.includes('product')) {
        const productMatch = shopifyAnalyticsScript.match(/var meta = ({.*?});/s);
        if (productMatch) {
          try {
            const metaData = JSON.parse(productMatch[1]);
            if (metaData.product && metaData.product.variants) {
              console.log(`  ✅ Found ${metaData.product.variants.length} variants in ShopifyAnalytics`);
              metaData.product.variants.slice(0, 3).forEach((variant, i) => {
                console.log(`    Variant ${i + 1}: ${variant.name || variant.title || 'Unknown'} - €${(variant.price / 100).toFixed(2)}`);
              });
              return;
            }
          } catch (e) {
            console.log('  ❌ Failed to parse ShopifyAnalytics meta');
          }
        }
      }
      
      // Test traditional JSON scripts
      const jsonScripts = $('script:contains("variants")');
      console.log(`  Found ${jsonScripts.length} scripts with 'variants'`);
      
      // Test HTML selectors
      const variantSelectors = $('select[name="id"], .product-form__option select');
      console.log(`  Found ${variantSelectors.length} variant selectors`);
      
    } catch (error) {
      console.log(`  ❌ Error testing variants: ${error.message}`);
    }
  }

  async testShoChaEnhanced() {
    console.log('\n🍃 Testing Enhanced Sho-Cha Crawling...');
    
    try {
      const response = await axios.get('https://www.sho-cha.com/teeshop', this.requestConfig);
      const $ = cheerio.load(response.data);
      
      const h1Elements = $('h1');
      console.log(`Found ${h1Elements.length} h1 elements`);
      
      for (let i = 0; i < Math.min(h1Elements.length, 3); i++) {
        const $h1 = $(h1Elements[i]);
        const name = $h1.text().trim();
        
        if (name && name.toLowerCase().includes('matcha')) {
          console.log(`\n--- Product: ${name} ---`);
          
          // Find corresponding teeshop link
          const section = $h1.closest('section, .product-section, .shop-section');
          let productUrl = null;
          
          if (section.length > 0) {
            const teeshopLink = section.find('a[href*="/teeshop/"]').first();
            if (teeshopLink.length > 0) {
              productUrl = 'https://www.sho-cha.com' + teeshopLink.attr('href');
              console.log(`Product URL: ${productUrl}`);
              
              // Test image extraction from product page
              await this.testShoChaProductImage(productUrl);
            } else {
              console.log('No teeshop link found in section');
            }
          } else {
            console.log('No section container found');
          }
        }
      }
      
    } catch (error) {
      console.error('❌ Error testing enhanced Sho-Cha:', error.message);
    }
  }

  async testShoChaProductImage(productUrl) {
    try {
      const response = await axios.get(productUrl, this.requestConfig);
      const $ = cheerio.load(response.data);
      
      const imageSelectors = [
        '.product-image img',
        '.shop-image img',
        '.main-image img',
        'img[src*="product"]',
        'img[src*="matcha"]',
        'img[src*="tea"]',
        'img[alt*="matcha" i]'
      ];
      
      console.log(`  Testing image selectors on product page...`);
      
      for (const selector of imageSelectors) {
        const img = $(selector).first();
        if (img.length) {
          const src = img.attr('src') || img.attr('data-src');
          console.log(`    ✅ ${selector}: ${src ? src.substring(0, 60) + '...' : 'NO SRC'}`);
          if (src) break; // Found an image
        } else {
          console.log(`    ❌ ${selector}: NOT FOUND`);
        }
      }
      
    } catch (error) {
      console.log(`  ❌ Error testing Sho-Cha image: ${error.message}`);
    }
  }

  async testHoriishichimeienStock() {
    console.log('\n🏯 Testing Enhanced Horiishichimeien Stock Tracking...');
    
    try {
      const response = await axios.get('https://horiishichimeien.com/en/collections/all?selected=%E6%8A%B9%E8%8C%B6', this.requestConfig);
      const $ = cheerio.load(response.data);
      
      const products = $('.grid__item').slice(0, 2);
      console.log(`Found ${products.length} products to test`);
      
      for (let i = 0; i < products.length; i++) {
        const $el = $(products[i]);
        const name = $el.find('a[href*="/products/"] span.visually-hidden, .card__heading, .product-title').text().trim();
        const link = $el.find('a[href*="/products/"]').first().attr('href');
        
        console.log(`\n--- Product ${i + 1}: ${name} ---`);
        
        if (link) {
          const productUrl = 'https://horiishichimeien.com' + link;
          console.log(`Product URL: ${productUrl}`);
          
          await this.testHoriishichimeienProductStock(productUrl);
        }
      }
      
    } catch (error) {
      console.error('❌ Error testing enhanced Horiishichimeien:', error.message);
    }
  }

  async testHoriishichimeienProductStock(productUrl) {
    try {
      const response = await axios.get(productUrl, this.requestConfig);
      const $ = cheerio.load(response.data);
      
      console.log(`  Testing stock selectors on product page...`);
      
      const addToCartSelectors = [
        '.product-form__buttons button:not([disabled])',
        '.product-form button[name="add"]:not([disabled])',
        'form[action="/cart/add"] button:not([disabled])',
        '.btn--add-to-cart:not([disabled])',
        'button:contains("Add to cart"):not([disabled])',
        'button:contains("カートに入れる"):not([disabled])'
      ];
      
      let stockStatus = 'UNKNOWN';
      
      for (const selector of addToCartSelectors) {
        const button = $(selector);
        if (button.length > 0) {
          const buttonText = button.text().trim();
          console.log(`    ✅ ${selector}: FOUND - "${buttonText}"`);
          if (!buttonText.toLowerCase().includes('sold out') && 
              !buttonText.toLowerCase().includes('out of stock')) {
            stockStatus = 'IN STOCK';
          }
          break;
        } else {
          console.log(`    ❌ ${selector}: NOT FOUND`);
        }
      }
      
      // Check for out of stock indicators
      const outOfStockSelectors = [
        ':contains("Sold out")',
        ':contains("Out of stock")',
        ':contains("売り切れ")',
        '.sold-out'
      ];
      
      for (const selector of outOfStockSelectors) {
        if ($(selector).length > 0) {
          console.log(`    ⚠️  OUT OF STOCK indicator found: ${selector}`);
          stockStatus = 'OUT OF STOCK';
          break;
        }
      }
      
      console.log(`    📊 Final stock status: ${stockStatus}`);
      
    } catch (error) {
      console.log(`  ❌ Error testing stock: ${error.message}`);
    }
  }
}

async function runComprehensiveTests() {
  const tester = new ComprehensiveTestCrawler();
  
  await tester.testPoppateaEnhanced();
  await tester.testShoChaEnhanced();
  await tester.testHoriishichimeienStock();
  
  console.log('\n✅ Comprehensive tests completed');
}

runComprehensiveTests().catch(console.error);
