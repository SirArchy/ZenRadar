const axios = require('axios');
const cheerio = require('cheerio');

(async () => {
  try {
    const response = await axios.get('https://poppatea.com/de-de/products/matcha-tea-ceremonial');
    const $ = cheerio.load(response.data);
    
    console.log('Looking for script tags with product data:');
    $('script').each((i, script) => {
      const text = $(script).text();
      if (text.includes('product') || text.includes('variants') || text.includes('window.')) {
        console.log(`Script ${i+1}: ${text.substring(0, 200)}...`);
        console.log('---');
        
        // Look for different JSON patterns
        const patterns = [
          /"product"\s*:\s*{[^}]+}/,
          /"variants"\s*:\s*\[[^\]]+\]/,
          /window\.shop\s*=\s*{[^}]+}/,
          /window\.product\s*=\s*{[^}]+}/,
          /var\s+product\s*=\s*{[^}]+}/
        ];
        
        patterns.forEach((pattern, pi) => {
          const match = text.match(pattern);
          if (match) {
            console.log(`  Pattern ${pi+1} match: ${match[0].substring(0, 200)}...`);
          }
        });
        
        // Also look for price elements
        if (text.includes('price') || text.includes('variant')) {
          console.log(`  Contains price/variant data`);
        }
        console.log('');
      }
    });
    
    // Also check for form elements with pricing
    console.log('\nChecking for form elements:');
    const forms = $('form[action*="/cart/add"]');
    console.log(`Found ${forms.length} cart forms`);
    
    forms.each((i, form) => {
      const $form = $(form);
      console.log(`Form ${i+1}:`);
      
      // Check for variant selectors
      const selects = $form.find('select[name="id"]');
      console.log(`  Variant selects: ${selects.length}`);
      
      selects.each((j, select) => {
        const $select = $(select);
        console.log(`    Select ${j+1}:`);
        $select.find('option').each((k, option) => {
          const $option = $(option);
          const value = $option.val();
          const text = $option.text();
          if (value && value !== '') {
            console.log(`      Option: ${text} (value: ${value})`);
          }
        });
      });
      
      // Check for hidden inputs
      const inputs = $form.find('input[type="hidden"]');
      console.log(`  Hidden inputs: ${inputs.length}`);
      inputs.each((j, input) => {
        const $input = $(input);
        const name = $input.attr('name');
        const value = $input.attr('value');
        if (name) {
          console.log(`    ${name}: ${value}`);
        }
      });
    });
    
  } catch (error) {
    console.error('Error:', error.message);
  }
})();
