const axios = require('axios');
const cheerio = require('cheerio');

async function testPoppateaSpecificProduct() {
  console.log('🛒 Testing Poppatea Variant Detection on Specific Product...');
  
  const userAgent = 'ZenRadar Bot 1.0 (+https://zenradar.app)';
  const requestConfig = {
    timeout: 30000,
    headers: {
      'User-Agent': userAgent,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9,de;q=0.8,sv;q=0.7',
      'Accept-Encoding': 'gzip, deflate, br',
      'DNT': '1',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
    }
  };
  
  try {
    const testUrl = 'https://poppatea.com/de-de/products/matcha-tea-ceremonial';
    console.log(`Testing: ${testUrl}`);
    
    const response = await axios.get(testUrl, requestConfig);
    const $ = cheerio.load(response.data);
    
    console.log('✅ Page loaded successfully');
    
    // Method 1: Look for window.ShopifyAnalytics meta
    console.log('\n📊 Testing ShopifyAnalytics detection...');
    const shopifyAnalyticsScript = $('script:contains("window.ShopifyAnalytics")').html();
    
    if (shopifyAnalyticsScript && shopifyAnalyticsScript.includes('product')) {
      console.log('Found ShopifyAnalytics script with product data');
      
      // Try different regex patterns to extract meta data
      const patterns = [
        /var meta = ({.*?});/s,
        /window\.ShopifyAnalytics\.meta = ({.*?});/s,
        /"product":\s*({.*?"variants"[^}]+})/s
      ];
      
      for (let i = 0; i < patterns.length; i++) {
        const pattern = patterns[i];
        const match = shopifyAnalyticsScript.match(pattern);
        
        if (match) {
          console.log(`Pattern ${i + 1} matched:`, match[1].substring(0, 150) + '...');
          
          try {
            const metaData = JSON.parse(match[1]);
            
            if (metaData.product && metaData.product.variants) {
              console.log(`🎯 SUCCESS: Found ${metaData.product.variants.length} variants!`);
              
              metaData.product.variants.forEach((variant, idx) => {
                console.log(`  Variant ${idx + 1}:`);
                console.log(`    Name: ${variant.name || variant.title || 'Unknown'}`);
                console.log(`    Price: €${(variant.price / 100).toFixed(2)}`);
                console.log(`    Available: ${variant.available}`);
                console.log(`    ID: ${variant.id}`);
              });
              
              return; // Success, exit function
            } else if (metaData.variants) {
              console.log(`🎯 SUCCESS: Found ${metaData.variants.length} variants (direct)!`);
              metaData.variants.forEach((variant, idx) => {
                console.log(`  Variant ${idx + 1}: ${JSON.stringify(variant)}`);
              });
              return;
            }
          } catch (e) {
            console.log(`Failed to parse JSON from pattern ${i + 1}:`, e.message);
          }
        } else {
          console.log(`Pattern ${i + 1} did not match`);
        }
      }
    } else {
      console.log('No ShopifyAnalytics script found or no product data');
    }
    
    // Method 2: Look for JSON scripts
    console.log('\n📊 Testing JSON script detection...');
    const jsonScripts = $('script[type="application/json"], script:contains("variants")');
    console.log(`Found ${jsonScripts.length} potential JSON scripts`);
    
    jsonScripts.each((index, script) => {
      const content = $(script).html();
      if (content && content.includes('variants') && content.length < 10000) {
        console.log(`\nScript ${index + 1} content (first 200 chars):`);
        console.log(content.substring(0, 200) + '...');
        
        try {
          const jsonData = JSON.parse(content);
          if (jsonData.variants) {
            console.log(`🎯 Found ${jsonData.variants.length} variants in JSON script!`);
          }
        } catch (e) {
          console.log('Not valid JSON');
        }
      }
    });
    
    // Method 3: Look for form selectors
    console.log('\n📊 Testing form selector detection...');
    const variantSelectors = $('select[name="id"], .product-form__option select, input[name="id"]');
    console.log(`Found ${variantSelectors.length} variant form elements`);
    
    variantSelectors.each((index, element) => {
      const $element = $(element);
      console.log(`\nForm element ${index + 1}: ${element.tagName}`);
      
      if ($element.is('select')) {
        const options = $element.find('option');
        console.log(`  Has ${options.length} options`);
        
        options.slice(0, 5).each((i, option) => {
          const $option = $(option);
          const value = $option.attr('value');
          const text = $option.text().trim();
          console.log(`    Option ${i + 1}: "${text}" (value: ${value})`);
        });
      }
    });
    
    console.log('\n📊 Testing image detection...');
    const imageSelectors = [
      '.product__media img',
      '.product-single__photos img',
      '.product__photo img',
      'img[src*="product"]',
      'img[src*="cdn/shop"]'
    ];
    
    for (const selector of imageSelectors) {
      const img = $(selector).first();
      if (img.length) {
        const src = img.attr('src') || img.attr('data-src');
        console.log(`✅ ${selector}: ${src ? src.substring(0, 80) + '...' : 'NO SRC'}`);
        if (src) break;
      } else {
        console.log(`❌ ${selector}: NOT FOUND`);
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

testPoppateaSpecificProduct();
