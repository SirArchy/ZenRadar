const axios = require('axios');
const cheerio = require('cheerio');

async function testPoppatea() {
  try {
    console.log('Testing Poppatea website...');
    
    const categoryUrl = 'https://poppatea.com/de-de/collections/all-teas?filter.p.m.custom.tea_type=Matcha';
    console.log('Fetching:', categoryUrl);
    
    const response = await axios.get(categoryUrl, {
      timeout: 30000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      }
    });
    
    console.log('Response status:', response.status);
    console.log('Response length:', response.data.length);
    
    const $ = cheerio.load(response.data);
    
    // Test product selectors
    const productSelectors = [
      '.product-item',
      '.grid__item',
      '.card',
      'a[href*="/products/"]'
    ];
    
    let bestSelector = null;
    let maxProducts = 0;
    
    for (const selector of productSelectors) {
      const elements = $(selector);
      console.log(`Product selector "${selector}": found ${elements.length} elements`);
      
      if (elements.length > maxProducts) {
        maxProducts = elements.length;
        bestSelector = selector;
      }
    }
    
    console.log('\nBest selector:', bestSelector, 'with', maxProducts, 'products');
    
    // Test first few products for price info
    const products = $(bestSelector);
    console.log('\nTesting price extraction from first few products:');
    
    products.slice(0, 3).each(async (i, el) => {
      const $el = $(el);
      const href = $el.attr('href') || $el.find('a').first().attr('href');
      const title = $el.text().trim().substring(0, 50);
      
      console.log(`\\nProduct ${i + 1}: "${title}"`);
      console.log(`Link: ${href}`);
      
      // Try to extract price from listing
      const priceSelectors = ['.price', '.money', '.price__regular', '.product-price'];
      for (const priceSelector of priceSelectors) {
        const priceEl = $el.find(priceSelector);
        if (priceEl.length > 0) {
          console.log(`  Price (${priceSelector}): "${priceEl.text().trim()}"`);
        }
      }
      
      // If we have a product link, test the product page
      if (href && href.startsWith('/')) {
        const fullUrl = 'https://poppatea.com' + href;
        console.log(`  Testing product page: ${fullUrl}`);
        
        try {
          const productResponse = await axios.get(fullUrl, {
            timeout: 15000,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
          });
          
          const $product = cheerio.load(productResponse.data);
          
          // Look for variants and prices
          const variantSelectors = ['select[name="id"]', '.product-form__option select', 'input[name="id"]'];
          
          for (const variantSelector of variantSelectors) {
            const variantEl = $product(variantSelector);
            if (variantEl.length > 0) {
              console.log(`    Found variant selector: ${variantSelector}`);
              variantEl.find('option').each((j, option) => {
                const $option = $product(option);
                const value = $option.attr('value');
                const text = $option.text().trim();
                if (value && text && !text.toLowerCase().includes('select')) {
                  console.log(`      Variant ${j}: "${text}" (value: ${value})`);
                }
              });
            }
          }
          
          // Look for JSON product data
          const scriptTags = $product('script[type="application/json"], script:contains("product")');
          scriptTags.each((j, script) => {
            const scriptContent = $product(script).html();
            if (scriptContent && scriptContent.includes('variants')) {
              console.log(`    Found product JSON in script ${j}`);
              try {
                const jsonData = JSON.parse(scriptContent);
                if (jsonData.variants) {
                  console.log(`      ${jsonData.variants.length} variants in JSON`);
                  jsonData.variants.slice(0, 2).forEach((variant, k) => {
                    console.log(`        Variant ${k}: ${variant.title}, price: ${variant.price}, available: ${variant.available}`);
                  });
                }
              } catch (e) {
                console.log(`      Failed to parse JSON: ${e.message}`);
              }
            }
          });
          
        } catch (error) {
          console.log(`    Error fetching product page: ${error.message}`);
        }
      }
    });
    
  } catch (error) {
    console.error('Error testing Poppatea:', error.message);
  }
}

testPoppatea();
