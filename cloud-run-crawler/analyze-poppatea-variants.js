const puppeteer = require('puppeteer');

async function analyzePoppateaVariants() {
  console.log('🔍 Analyzing Poppatea Product Variants\n');
  
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  
  try {
    await page.goto('https://poppatea.com/de-de/collections/all-teas', { 
      waitUntil: 'networkidle2',
      timeout: 30000 
    });

    // Get all product cards with titles
    const productCards = await page.$$eval('.card', cards => {
      return cards
        .filter(card => card.querySelector('.card__title'))
        .map(card => {
          const titleElement = card.querySelector('.card__title a');
          const priceElement = card.querySelector('.card__price');
          
          return {
            title: titleElement ? titleElement.textContent.trim() : null,
            url: titleElement ? titleElement.href : null,
            price: priceElement ? priceElement.textContent.trim() : null
          };
        })
        .filter(product => product.title && product.url);
    });

    console.log(`Found ${productCards.length} product cards with titles`);
    
    // Analyze each product for variants
    for (let i = 0; i < productCards.length; i++) {
      const product = productCards[i];
      console.log(`\n📦 Analyzing Product ${i + 1}: ${product.title}`);
      console.log(`   URL: ${product.url}`);
      console.log(`   List Price: ${product.price}`);
      
      // Navigate to product page to check for variants
      try {
        await page.goto(product.url, { 
          waitUntil: 'networkidle2',
          timeout: 15000 
        });
        
        // Look for variant selectors
        const variantData = await page.evaluate(() => {
          const variants = [];
          
          // Check for variant select elements
          const variantSelectors = document.querySelectorAll('select[name*="variant"], select.variant-selector, .variant-wrapper select');
          
          if (variantSelectors.length > 0) {
            variantSelectors.forEach(select => {
              const options = Array.from(select.options);
              options.forEach(option => {
                if (option.value && option.text && option.value !== '') {
                  variants.push({
                    type: 'select',
                    value: option.value,
                    text: option.text.trim(),
                    selected: option.selected
                  });
                }
              });
            });
          }
          
          // Check for variant buttons/radio buttons
          const variantButtons = document.querySelectorAll('.variant-option, .swatch, input[name*="variant"]');
          variantButtons.forEach(button => {
            if (button.value && (button.textContent || button.getAttribute('title'))) {
              variants.push({
                type: 'button',
                value: button.value,
                text: (button.textContent || button.getAttribute('title')).trim(),
                checked: button.checked || button.classList.contains('selected')
              });
            }
          });
          
          // Look for JSON variant data
          const scripts = Array.from(document.querySelectorAll('script'));
          let jsonVariants = [];
          
          scripts.forEach(script => {
            const content = script.textContent;
            if (content.includes('variants') && content.includes('available')) {
              try {
                // Look for Shopify product JSON
                const matches = content.match(/"variants"\s*:\s*\[(.*?)\]/s);
                if (matches) {
                  const variantString = '[' + matches[1] + ']';
                  const parsed = JSON.parse(variantString);
                  jsonVariants = parsed.map(v => ({
                    type: 'json',
                    id: v.id,
                    title: v.title || v.name || 'Unknown',
                    price: v.price,
                    available: v.available,
                    sku: v.sku
                  }));
                }
              } catch (e) {
                // Ignore parsing errors
              }
            }
          });
          
          return {
            domVariants: variants,
            jsonVariants: jsonVariants,
            title: document.querySelector('.product-title, h1')?.textContent?.trim(),
            price: document.querySelector('.price, .product-price')?.textContent?.trim()
          };
        });
        
        console.log(`   DOM Variants: ${variantData.domVariants.length}`);
        console.log(`   JSON Variants: ${variantData.jsonVariants.length}`);
        
        if (variantData.domVariants.length > 0) {
          console.log('   DOM Variant Details:');
          variantData.domVariants.forEach((variant, idx) => {
            console.log(`     ${idx + 1}. ${variant.text} (${variant.value}) [${variant.type}]`);
          });
        }
        
        if (variantData.jsonVariants.length > 0) {
          console.log('   JSON Variant Details:');
          variantData.jsonVariants.forEach((variant, idx) => {
            console.log(`     ${idx + 1}. ${variant.title} - €${(variant.price / 100).toFixed(2)} - Available: ${variant.available}`);
          });
        }
        
        if (variantData.domVariants.length === 0 && variantData.jsonVariants.length === 0) {
          console.log('   ❌ No variants found - single product');
        }
        
      } catch (error) {
        console.log(`   ❌ Error analyzing product page: ${error.message}`);
      }
    }
    
  } catch (error) {
    console.log('❌ Error:', error.message);
  } finally {
    await browser.close();
  }
}

analyzePoppateaVariants().catch(console.error);
