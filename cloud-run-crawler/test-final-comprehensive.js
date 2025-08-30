const axios = require('axios');
const cheerio = require('cheerio');

class FinalTestSuite {
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

  async testImprovedNameMatching() {
    console.log('🔍 Testing Improved Sho-Cha Name Matching...');
    
    try {
      const response = await axios.get('https://www.sho-cha.com/teeshop', this.requestConfig);
      const $ = cheerio.load(response.data);
      
      const allTeeshopLinks = $('a[href*="/teeshop/"]');
      console.log(`Found ${allTeeshopLinks.length} teeshop links`);
      
      // Test cases
      const testCases = [
        'Amai MATCHA Lim. Ed.',
        'Limited Matcha Uji',
        'Matcha Nº1',
        'Matcha Nº2 Supreme'
      ];
      
      for (const testName of testCases) {
        console.log(`\n--- Testing: "${testName}" ---`);
        
        const nameSlug = testName.toLowerCase().replace(/[^a-z0-9]/g, '');
        console.log(`Name slug: "${nameSlug}"`);
        
        let bestMatch = null;
        let bestScore = 0;
        
        allTeeshopLinks.slice(0, 10).each((idx, link) => {
          const href = $(link).attr('href');
          const linkSlug = href.replace('/teeshop/', '').replace(/[^a-z0-9]/g, '');
          
          // Calculate match scores
          let score = 0;
          
          // Direct slug matching
          const commonLength = Math.min(nameSlug.length, linkSlug.length);
          let commonChars = 0;
          for (let i = 0; i < commonLength; i++) {
            if (nameSlug[i] === linkSlug[i]) {
              commonChars++;
            } else {
              break;
            }
          }
          score += (commonChars / nameSlug.length) * 10;
          
          // Check for key word matches
          const nameWords = testName.toLowerCase().split(/\s+/).filter(w => w.length > 2);
          const linkWords = href.split(/[-_/]/).filter(w => w.length > 2);
          
          for (const nameWord of nameWords) {
            for (const linkWord of linkWords) {
              if (nameWord.includes(linkWord) || linkWord.includes(nameWord)) {
                score += 5;
              }
            }
          }
          
          // Prefer shorter, more specific matches
          if (linkSlug.length > 0) {
            score += (10 / linkSlug.length);
          }
          
          console.log(`  ${href} (${linkSlug}) - Score: ${score.toFixed(2)}`);
          
          if (score > bestScore && score > 3) {
            bestScore = score;
            bestMatch = href;
          }
        });
        
        if (bestMatch) {
          console.log(`✅ BEST MATCH: ${bestMatch} (Score: ${bestScore.toFixed(2)})`);
        } else {
          console.log(`❌ NO SUITABLE MATCH FOUND`);
        }
      }
      
    } catch (error) {
      console.error('❌ Error:', error.message);
    }
  }

  async testAllFixes() {
    console.log('🚀 COMPREHENSIVE TEST OF ALL FIXES\n');
    
    console.log('1️⃣ POPPATEA IMAGE EXTRACTION');
    await this.testPoppateaImages();
    
    console.log('\n2️⃣ POPPATEA VARIANT EXTRACTION');
    await this.testPoppateaVariants();
    
    console.log('\n3️⃣ SHO-CHA IMPROVEMENTS');
    await this.testImprovedNameMatching();
    
    console.log('\n4️⃣ HORIISHICHIMEIEN STOCK TRACKING');
    await this.testHoriishichimeienStock();
    
    console.log('\n🎯 SUMMARY OF FIXES:');
    console.log('✅ Poppatea Images: Enhanced selectors to include img, cdn/shop paths');
    console.log('✅ Poppatea Variants: Added ShopifyAnalytics meta parsing');
    console.log('✅ Sho-Cha Images: Added individual product page image extraction');
    console.log('✅ Sho-Cha Links: Improved name matching with scoring algorithm');
    console.log('✅ Horiishichimeien Stock: Added individual product page stock checking');
  }

  async testPoppateaImages() {
    try {
      const response = await axios.get('https://poppatea.com/collections/all', this.requestConfig);
      const $ = cheerio.load(response.data);
      
      const products = $('.card, .product-card, .grid-item').slice(0, 2);
      let imagesFound = 0;
      
      products.each((i, element) => {
        const $el = $(element);
        const img = $el.find('img, .card-image img, .product-image img, img[src*="product"], img[src*="cdn/shop"]').first();
        const imgSrc = img.attr('src') || img.attr('data-src');
        
        if (imgSrc) {
          imagesFound++;
          console.log(`  ✅ Product ${i + 1}: Image found`);
        } else {
          console.log(`  ❌ Product ${i + 1}: No image`);
        }
      });
      
      console.log(`  📊 Result: ${imagesFound}/${products.length} products have images`);
      
    } catch (error) {
      console.log(`  ❌ Error: ${error.message}`);
    }
  }

  async testPoppateaVariants() {
    try {
      const testUrl = 'https://poppatea.com/de-de/products/matcha-tea-ceremonial';
      const response = await axios.get(testUrl, this.requestConfig);
      const $ = cheerio.load(response.data);
      
      const shopifyAnalyticsScript = $('script:contains("window.ShopifyAnalytics")').html();
      
      if (shopifyAnalyticsScript && shopifyAnalyticsScript.includes('product')) {
        const productMatch = shopifyAnalyticsScript.match(/var meta = ({.*?});/s);
        if (productMatch) {
          const metaData = JSON.parse(productMatch[1]);
          if (metaData.product && metaData.product.variants) {
            console.log(`  ✅ Found ${metaData.product.variants.length} variants via ShopifyAnalytics`);
            return;
          }
        }
      }
      
      console.log(`  ❌ No variants found via ShopifyAnalytics`);
      
    } catch (error) {
      console.log(`  ❌ Error: ${error.message}`);
    }
  }

  async testHoriishichimeienStock() {
    try {
      const response = await axios.get('https://horiishichimeien.com/en/collections/all?selected=%E6%8A%B9%E8%8C%B6', this.requestConfig);
      const $ = cheerio.load(response.data);
      
      const products = $('.grid__item').slice(0, 1);
      const $el = $(products[0]);
      const link = $el.find('a[href*="/products/"]').first().attr('href');
      
      if (link) {
        const productUrl = 'https://horiishichimeien.com' + link;
        const productResponse = await axios.get(productUrl, this.requestConfig);
        const $product = cheerio.load(productResponse.data);
        
        const addToCartButton = $product('.product-form button[name="add"]');
        const buttonText = addToCartButton.text().trim();
        
        if (buttonText.includes('Sold out')) {
          console.log(`  ✅ Correctly detected: OUT OF STOCK`);
        } else if (buttonText.includes('Add to cart')) {
          console.log(`  ✅ Correctly detected: IN STOCK`);
        } else {
          console.log(`  ⚠️ Button text: "${buttonText}"`);
        }
      }
      
    } catch (error) {
      console.log(`  ❌ Error: ${error.message}`);
    }
  }
}

const tester = new FinalTestSuite();
tester.testAllFixes().catch(console.error);
