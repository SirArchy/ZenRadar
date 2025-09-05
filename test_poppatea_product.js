const axios = require('axios');
const cheerio = require('cheerio');

async function testPoppateaProductPage() {
  console.log('Testing Poppatea product page for variants...');
  
  try {
    // Test the ceremonial matcha product page
    const productUrl = 'https://poppatea.com/de-de/products/matcha-tea-ceremonial';
    
    const response = await axios.get(productUrl, {
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
    
    console.log(`✅ Successfully fetched product page (${response.status})`);
    
    const $ = cheerio.load(response.data);
    
    // Look for Shopify product JSON (most common for variants)
    console.log('\n🔍 Looking for Shopify product JSON...');
    let foundProductJson = false;
    const scriptTags = $('script');
    
    scriptTags.each((_, script) => {
      const scriptContent = $(script).html();
      if (scriptContent && scriptContent.includes('"product"') && scriptContent.includes('"variants"')) {
        console.log('📦 Found product JSON script!');
        
        // Try to extract the JSON
        const jsonMatch = scriptContent.match(/window\\.ShopifyProduct\\s*=\\s*({.*?});/) || 
                         scriptContent.match(/"product"\\s*:\\s*({.*?})(?:,|$)/);
        
        if (jsonMatch) {
          try {
            const productData = JSON.parse(jsonMatch[1]);
            console.log(`📋 Product: ${productData.title || 'Unknown'}`);
            console.log(`💰 Price: ${productData.price || 'Unknown'}`);
            console.log(`🏷️  Variants: ${productData.variants ? productData.variants.length : 'None'}`);
            
            if (productData.variants) {
              productData.variants.forEach((variant, index) => {
                console.log(`  ${index + 1}. ${variant.title || variant.name || 'Unknown'} - €${(variant.price / 100).toFixed(2)}`);
              });
            }
            foundProductJson = true;
          } catch (e) {
            console.log('❌ Failed to parse product JSON:', e.message);
          }
        }
      }
    });
    
    if (!foundProductJson) {
      console.log('❌ No Shopify product JSON found');
    }
    
    // Look for variant form elements
    console.log('\n🔍 Looking for variant form elements...');
    const variantSelects = $('select[name*="variant"], select[name="id"]');
    console.log(`📋 Variant select elements: ${variantSelects.length}`);
    
    variantSelects.each((index, select) => {
      const $select = $(select);
      const options = $select.find('option');
      console.log(`Select ${index + 1}: ${options.length} options`);
      
      options.each((optIndex, option) => {
        const $option = $(option);
        const value = $option.attr('value');
        const text = $option.text().trim();
        if (text && text !== 'Select variant' && text !== 'Select size') {
          console.log(`  Option: ${text} (value: ${value})`);
        }
      });
    });
    
    // Look for variant buttons/labels
    console.log('\n🔍 Looking for variant buttons/labels...');
    const variantButtons = $('.variant-option, .variant-button, .size-option, input[type="radio"][name*="variant"]');
    console.log(`📋 Variant button elements: ${variantButtons.length}`);
    
    variantButtons.each((index, button) => {
      const $button = $(button);
      const text = $button.text().trim() || $button.attr('value') || $button.attr('data-value');
      console.log(`  Button ${index + 1}: ${text}`);
    });
    
    // Look for pricing information
    console.log('\n💰 Looking for pricing information...');
    const priceElements = $('.price, .money, .amount, .cost');
    console.log(`💰 Price elements found: ${priceElements.length}`);
    
    priceElements.each((index, priceEl) => {
      const $price = $(priceEl);
      const priceText = $price.text().trim();
      if (priceText && priceText.length < 50) {
        console.log(`  Price ${index + 1}: "${priceText}"`);
      }
    });
    
    // Check if there's a form for adding to cart
    console.log('\n🛒 Looking for add to cart form...');
    const cartForms = $('form[action*="/cart/add"], form[action*="cart"], .product-form');
    console.log(`🛒 Cart forms found: ${cartForms.length}`);
    
    cartForms.each((index, form) => {
      const $form = $(form);
      const inputs = $form.find('input, select');
      console.log(`  Form ${index + 1}: ${inputs.length} input elements`);
    });
    
  } catch (error) {
    console.error('❌ Error testing product page:', error.message);
    if (error.response) {
      console.error('Response status:', error.response.status);
    }
  }
}

testPoppateaProductPage();
