const axios = require('axios');
const cheerio = require('cheerio');

async function analyzePoppateaCorrectStructure() {
  console.log('🔍 Analyzing Correct Poppatea Website Structure\n');
  
  const baseUrl = 'https://poppatea.com';
  const testUrls = [
    'https://poppatea.com/de-de/collections/all-teas',
    'https://poppatea.com/de-de/collections/all-teas/products/matcha-tea-ceremonial',
    'https://poppatea.com/de-de/collections/all-teas/products/hojicha-tea-powder',
    'https://poppatea.com/de-de/collections/all-teas/products/matcha-tea-with-chai-ceremonial'
  ];

  for (const url of testUrls) {
    console.log(`\n🌐 Testing URL: ${url}`);
    
    try {
      const response = await axios.get(url, {
        timeout: 15000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
        }
      });
      
      console.log(`✅ Success! Status: ${response.status}`);
      console.log(`📄 Content length: ${response.data.length} characters`);
      
      const $ = cheerio.load(response.data);
      
      // Analyze page structure
      console.log('\n📊 Page Analysis:');
      console.log(`Title: ${$('title').text().trim()}`);
      
      if (url.includes('/collections/')) {
        console.log('\n🛍️ COLLECTION PAGE ANALYSIS:');
        
        // Look for product containers with various selectors
        const productSelectors = [
          '.product-item',
          '.product-card',
          '.grid-item',
          '.product',
          '[data-product]',
          '.collection-product',
          '.product-grid-item',
          '.card-product',
          '.product-block',
          '.grid__item',
          '.card',
          '.product-wrap',
          'article',
          '.item'
        ];
        
        console.log('\n🔍 Product Container Analysis:');
        let bestSelector = null;
        let maxProducts = 0;
        
        for (const selector of productSelectors) {
          const elements = $(selector);
          if (elements.length > 0) {
            console.log(`✅ ${selector}: ${elements.length} elements found`);
            
            if (elements.length > maxProducts) {
              maxProducts = elements.length;
              bestSelector = selector;
            }
            
            // Analyze first element structure
            const firstElement = elements.first();
            
            // Look for product links and names
            const links = firstElement.find('a[href*="product"]');
            const titles = firstElement.find('h1, h2, h3, h4, .title, .name, .product-title, .card-title');
            const prices = firstElement.find('.price, .cost, .amount, [class*="price"], .money');
            
            console.log(`   - Links found: ${links.length}`);
            console.log(`   - Title elements: ${titles.length}`);
            console.log(`   - Price elements: ${prices.length}`);
            
            if (links.length > 0) {
              console.log(`   - Sample link: ${links.first().attr('href')}`);
            }
            if (titles.length > 0) {
              console.log(`   - Sample title: "${titles.first().text().trim()}"`);
            }
            if (prices.length > 0) {
              console.log(`   - Sample price: "${prices.first().text().trim()}"`);
            }
            
            // Show sample HTML structure
            if (elements.length > 0 && (links.length > 0 || titles.length > 0)) {
              console.log(`   Sample HTML structure:`);
              const sampleHtml = firstElement.html();
              console.log(`   ${sampleHtml.substring(0, 300)}...`);
            }
          }
        }
        
        if (bestSelector) {
          console.log(`\n🎯 BEST SELECTOR: ${bestSelector} (${maxProducts} products)`);
        }
        
      } else if (url.includes('/products/')) {
        console.log('\n📦 PRODUCT PAGE ANALYSIS:');
        
        // Analyze product page structure
        const productName = $('h1, .product-title, .product__title, .page-title').first().text().trim();
        console.log(`Product Name: "${productName}"`);
        
        // Look for price selectors
        const priceSelectors = [
          '.price',
          '.product-price',
          '.money',
          '.cost',
          '.amount',
          '[data-price]',
          '.price--current',
          '.price-current'
        ];
        
        console.log('\n💰 Price Analysis:');
        for (const selector of priceSelectors) {
          const priceElements = $(selector);
          if (priceElements.length > 0) {
            console.log(`✅ ${selector}: ${priceElements.length} elements`);
            priceElements.each((i, el) => {
              const text = $(el).text().trim();
              if (text) {
                console.log(`   - Price ${i + 1}: "${text}"`);
              }
            });
          }
        }
        
        // Look for variant selectors
        const variantSelectors = [
          'select[name*="id"]',
          'input[name*="id"]',
          '.variant-selector',
          '.product-variants',
          '.product-options',
          'option[value]',
          '[data-variant]'
        ];
        
        console.log('\n🔄 Variant Analysis:');
        for (const selector of variantSelectors) {
          const variantElements = $(selector);
          if (variantElements.length > 0) {
            console.log(`✅ ${selector}: ${variantElements.length} elements`);
            if (selector.includes('option')) {
              variantElements.each((i, el) => {
                const text = $(el).text().trim();
                const value = $(el).attr('value');
                if (text && value) {
                  console.log(`   - Option ${i + 1}: "${text}" (value: ${value})`);
                }
              });
            }
          }
        }
        
        // Check for JSON-LD or window.meta data
        console.log('\n📋 Structured Data Analysis:');
        const scripts = $('script[type="application/ld+json"], script[type="application/json"]');
        console.log(`JSON-LD scripts found: ${scripts.length}`);
        
        // Look for window variables
        const pageText = response.data;
        if (pageText.includes('window.meta')) {
          console.log('✅ window.meta detected');
        }
        if (pageText.includes('product:')) {
          console.log('✅ Product data detected in scripts');
        }
        if (pageText.includes('variants:')) {
          console.log('✅ Variants data detected in scripts');
        }
      }
      
      // Look for Shopify indicators
      console.log('\n🛍️ E-commerce Platform Detection:');
      if (response.data.includes('Shopify')) {
        console.log('✅ Shopify platform detected');
      }
      if (response.data.includes('product-form')) {
        console.log('✅ Product forms detected');
      }
      if (response.data.includes('collection')) {
        console.log('✅ Collection pages detected');
      }
      
    } catch (error) {
      console.log(`❌ Failed: ${error.message}`);
    }
    
    console.log('\n' + '─'.repeat(80));
  }
  
  console.log('\n✨ Analysis Complete!');
}

if (require.main === module) {
  analyzePoppateaCorrectStructure().catch(console.error);
}
