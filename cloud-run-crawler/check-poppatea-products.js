const axios = require('axios');
const cheerio = require('cheerio');

async function checkIndividualProducts() {
  console.log('🔍 Checking Individual Poppatea Product Pages for Variants\n');
  
  const productUrls = [
    'https://poppatea.com/de-de/collections/all-teas/products/matcha-tea-ceremonial',
    'https://poppatea.com/de-de/collections/all-teas/products/matcha-tea-with-chai-ceremonial',
    'https://poppatea.com/de-de/collections/all-teas/products/hojicha-tea-powder'
  ];

  const requestConfig = {
    timeout: 30000,
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5'
    }
  };

  for (let i = 0; i < productUrls.length; i++) {
    const url = productUrls[i];
    console.log(`\n📦 Product ${i + 1}: ${url.split('/').pop()}`);
    
    try {
      const response = await axios.get(url, requestConfig);
      const $ = cheerio.load(response.data);
      
      // Get product title
      const title = $('.product-title, h1, .product__title').first().text().trim();
      console.log(`   Title: ${title}`);
      
      // Look for variant selectors
      const variantSelects = $('select[name="id"], select[name*="variant"], .variant-selector select');
      console.log(`   Variant Select Elements: ${variantSelects.length}`);
      
      if (variantSelects.length > 0) {
        variantSelects.each((idx, select) => {
          const options = $(select).find('option');
          console.log(`     Select ${idx + 1}: ${options.length} options`);
          options.each((optIdx, option) => {
            const value = $(option).attr('value');
            const text = $(option).text().trim();
            const disabled = $(option).attr('disabled');
            if (value && text && !disabled) {
              console.log(`       - ${text} (ID: ${value})`);
            }
          });
        });
      }
      
      // Look for variant buttons
      const variantButtons = $('.variant-option, .swatch, input[type="radio"][name*="variant"]');
      console.log(`   Variant Buttons: ${variantButtons.length}`);
      
      // Look for JSON product data
      let foundProductJson = false;
      $('script').each((idx, script) => {
        const content = $(script).html();
        if (content && (content.includes('"variants"') || content.includes('"product"'))) {
          try {
            // Try to find product JSON
            const productMatches = content.match(/"product"\s*:\s*\{[^}]+?"variants"\s*:\s*\[[^\]]*\]/);
            if (productMatches) {
              console.log(`   ✅ Found product JSON with variants in script ${idx}`);
              foundProductJson = true;
              
              // Try to extract variant count
              const variantMatches = content.match(/"variants"\s*:\s*\[([^\]]*)\]/);
              if (variantMatches) {
                try {
                  const variantArray = JSON.parse('[' + variantMatches[1] + ']');
                  console.log(`     JSON Variants: ${variantArray.length}`);
                  variantArray.slice(0, 3).forEach((variant, vIdx) => {
                    console.log(`       ${vIdx + 1}. ${variant.title || variant.name || 'Unnamed'} - €${(variant.price / 100).toFixed(2)} - Available: ${variant.available}`);
                  });
                } catch (e) {
                  console.log(`     Could not parse variants JSON: ${e.message}`);
                }
              }
              return false; // Break out of each loop
            }
          } catch (e) {
            // Continue to next script
          }
        }
      });
      
      if (!foundProductJson) {
        console.log(`   ❌ No product JSON with variants found`);
      }
      
      // Check for price information
      const priceElements = $('.price, .money, .product-price, .price__current');
      console.log(`   Price Elements: ${priceElements.length}`);
      priceElements.each((idx, priceEl) => {
        const priceText = $(priceEl).text().trim();
        if (priceText) {
          console.log(`     Price ${idx + 1}: "${priceText}"`);
        }
      });
      
    } catch (error) {
      console.log(`   ❌ Error: ${error.message}`);
    }
  }
}

checkIndividualProducts().catch(console.error);
