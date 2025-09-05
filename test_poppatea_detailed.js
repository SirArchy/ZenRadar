const axios = require('axios');
const cheerio = require('cheerio');

async function testPoppateaProductPageDetailed() {
  console.log('Testing Poppatea product page for variants (detailed)...');
  
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
    
    // Look for ANY script tags containing product data
    console.log('\n🔍 Analyzing all script tags...');
    let scriptIndex = 0;
    const scriptTags = $('script');
    
    scriptTags.each((_, script) => {
      const scriptContent = $(script).html();
      if (scriptContent && scriptContent.length > 0) {
        scriptIndex++;
        
        // Look for different patterns of product/variant data
        if (scriptContent.includes('product') || scriptContent.includes('variant') || scriptContent.includes('price')) {
          console.log(`\n📜 Script ${scriptIndex} (${scriptContent.length} chars):`);
          
          // Check for different JSON patterns
          if (scriptContent.includes('"variants"')) {
            console.log('  ✓ Contains "variants"');
            
            // Try different JSON extraction patterns
            const patterns = [
              /window\.ShopifyProduct\s*=\s*({.*?});/s,
              /"product"\s*:\s*({.*?})(?:,|\}|$)/s,
              /ShopifyProduct\s*=\s*({.*?});/s,
              /product.*?=.*?({.*?variants.*?})/s,
              /"variants"\s*:\s*(\[.*?\])/s
            ];
            
            for (let i = 0; i < patterns.length; i++) {
              const match = scriptContent.match(patterns[i]);
              if (match) {
                console.log(`  ✓ Pattern ${i + 1} matched!`);
                
                try {
                  let jsonData;
                  if (i === 4) {
                    // Just variants array
                    jsonData = { variants: JSON.parse(match[1]) };
                  } else {
                    jsonData = JSON.parse(match[1]);
                  }
                  
                  if (jsonData.variants) {
                    console.log(`  📦 Found ${jsonData.variants.length} variants:`);
                    jsonData.variants.forEach((variant, idx) => {
                      console.log(`    ${idx + 1}. ${variant.title || variant.name || 'Unknown'} - ${variant.price ? '€' + (variant.price / 100).toFixed(2) : 'No price'}`);
                    });
                    
                    return false; // Break out of each loop
                  }
                } catch (e) {
                  console.log(`  ❌ Failed to parse JSON from pattern ${i + 1}: ${e.message.slice(0, 100)}`);
                }
              }
            }
          }
          
          if (scriptContent.includes('price') && scriptContent.includes('€')) {
            console.log('  ✓ Contains prices');
            
            // Look for price patterns
            const priceMatches = scriptContent.match(/€\s*\d+[,.]?\d*/g);
            if (priceMatches) {
              console.log(`  💰 Found prices: ${priceMatches.slice(0, 5).join(', ')}`);
            }
          }
          
          // Show first 200 chars if it looks interesting
          if (scriptContent.includes('variant') || scriptContent.includes('Dose') || scriptContent.includes('Nachfüllbeutel')) {
            console.log(`  📝 Preview: ${scriptContent.slice(0, 200).replace(/\n/g, ' ')}...`);
          }
        }
      }
    });
    
    // Look for forms with more detail
    console.log('\n🛒 Analyzing cart forms in detail...');
    const cartForms = $('form[action*="/cart/add"], form[action*="cart"], .product-form');
    
    cartForms.each((index, form) => {
      const $form = $(form);
      console.log(`\n🛒 Form ${index + 1}:`);
      console.log(`  Action: ${$form.attr('action')}`);
      console.log(`  Method: ${$form.attr('method')}`);
      
      const inputs = $form.find('input, select, button');
      inputs.each((inputIndex, input) => {
        const $input = $(input);
        const type = $input.attr('type') || $input[0].tagName.toLowerCase();
        const name = $input.attr('name');
        const value = $input.attr('value');
        const text = $input.text().trim();
        
        if (name || value || (text && text.length > 0 && text.length < 50)) {
          console.log(`    Input ${inputIndex + 1}: ${type} name="${name}" value="${value}" text="${text}"`);
        }
      });
    });
    
    // Look for any elements that might contain variant information
    console.log('\n🔍 Looking for variant-related elements...');
    const possibleVariantElements = $('[class*="variant"], [class*="option"], [class*="size"], [id*="variant"], [id*="option"]');
    console.log(`Found ${possibleVariantElements.length} potential variant elements`);
    
    possibleVariantElements.each((index, el) => {
      const $el = $(el);
      const tagName = el.tagName.toLowerCase();
      const className = $el.attr('class');
      const id = $el.attr('id');
      const text = $el.text().trim();
      
      if (text && text.length < 100) {
        console.log(`  ${index + 1}. ${tagName}.${className}#${id}: "${text}"`);
      }
    });
    
  } catch (error) {
    console.error('❌ Error testing product page:', error.message);
    if (error.response) {
      console.error('Response status:', error.response.status);
    }
  }
}

testPoppateaProductPageDetailed();
