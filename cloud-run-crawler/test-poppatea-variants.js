const axios = require('axios');
const cheerio = require('cheerio');

// Simulate the enhanced variant extraction logic
async function testPoppateaVariants(productUrl) {
  try {
    const response = await axios.get(productUrl);
    const $ = cheerio.load(response.data);
    
    console.log(`Testing: ${productUrl}`);
    console.log(`Response status: ${response.status}`);
    
    // Method 1: Enhanced JSON detection
    let foundVariants = [];
    
    $('script').each((i, script) => {
      const text = $(script).text().trim();
      
      // Look for ShopifyAnalytics meta with product data
      const metaMatch = text.match(/window\.ShopifyAnalytics\.meta\s*=\s*window\.ShopifyAnalytics\.meta\s*\|\|\s*\{\};\s*var\s+meta\s*=\s*(\{[^;]+\});/s);
      if (metaMatch) {
        try {
          const metaJson = metaMatch[1];
          const parsed = JSON.parse(metaJson);
          if (parsed.product && parsed.product.variants) {
            console.log(`Found ShopifyAnalytics meta with ${parsed.product.variants.length} variants`);
            foundVariants = parsed.product.variants;
            return false; // Break
          }
        } catch (e) {
          console.log(`Failed to parse ShopifyAnalytics meta: ${e.message}`);
        }
      }
      
      // Look for direct variant arrays
      const variantMatches = text.match(/(\[\s*\{\s*"id":\s*\d+[^}]+\}[^\]]*\])/g);
      if (variantMatches) {
        for (const match of variantMatches) {
          try {
            const variants = JSON.parse(match);
            if (Array.isArray(variants) && variants.length > 0 && variants[0].id && variants[0].price !== undefined) {
              console.log(`Found variant array in script ${i + 1} with ${variants.length} variants`);
              foundVariants = variants;
              return false;
            }
          } catch (e) {
            // Continue
          }
        }
      }
    });
    
    // Display found variants
    if (foundVariants.length > 0) {
      console.log(`\nFound ${foundVariants.length} variants:`);
      foundVariants.forEach((variant, i) => {
        const price = variant.price ? (variant.price > 100 ? variant.price / 100 : variant.price) : 0;
        const title = variant.title || variant.public_title || variant.option1 || 'Default';
        console.log(`  ${i + 1}. ${title}`);
        console.log(`     Price: €${price.toFixed(2)} (raw: ${variant.price})`);
        console.log(`     Available: ${variant.available !== false}`);
        console.log(`     ID: ${variant.id}`);
      });
    } else {
      console.log('No variants found in JSON');
      
      // Fallback: check forms
      const forms = $('form[action*="/cart/add"]');
      console.log(`Found ${forms.length} cart forms`);
      
      forms.each((i, form) => {
        const $form = $(form);
        const variantId = $form.find('input[name="id"]').val();
        if (variantId) {
          console.log(`  Form ${i + 1}: variant ID ${variantId}`);
        }
      });
    }
    
    return foundVariants;
    
  } catch (error) {
    console.error('Error:', error.message);
    return [];
  }
}

async function testMultipleProducts() {
  const testUrls = [
    'https://poppatea.com/de-de/products/matcha-tea-ceremonial',
    'https://poppatea.com/de-de/products/matcha-tea-with-chai-ceremonial'
  ];
  
  for (const url of testUrls) {
    console.log('\n' + '='.repeat(80));
    await testPoppateaVariants(url);
    console.log('');
  }
}

testMultipleProducts();
