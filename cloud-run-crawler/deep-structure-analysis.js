const axios = require('axios');
const cheerio = require('cheerio');

async function analyzeStructureDeep() {
  console.log('=== Deep Structure Analysis ===');
  
  // Analyze Matcha Kāru structure
  console.log('\n--- Matcha Kāru Analysis ---');
  try {
    const response = await axios.get('https://matcha-karu.com/collections/matcha-tee', {
      timeout: 30000,
      headers: {
        'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      }
    });

    const $ = cheerio.load(response.data);
    const productElements = $('.product-item');
    
    console.log(`Found ${productElements.length} .product-item elements`);
    
    // Analyze first product structure in detail
    if (productElements.length > 0) {
      const firstProduct = $(productElements[0]);
      console.log('\nFirst product HTML structure:');
      console.log(firstProduct.html().substring(0, 1000) + '...');
      
      // Look for all possible name selectors
      const nameSelectors = [
        'a[href*="/products/"]',
        '.product-title',
        '.product-name', 
        'h3',
        'h4',
        '.card-title',
        '.product-item__title',
        '[data-product-title]'
      ];
      
      console.log('\nTesting name selectors:');
      nameSelectors.forEach(selector => {
        const found = firstProduct.find(selector);
        if (found.length > 0) {
          found.each((i, el) => {
            const text = $(el).text().trim();
            const href = $(el).attr('href');
            console.log(`  ${selector}: "${text}" ${href ? `(href: ${href})` : ''}`);
          });
        }
      });
      
      // Look at all links in the product
      console.log('\nAll links in first product:');
      firstProduct.find('a').each((i, el) => {
        const href = $(el).attr('href');
        const text = $(el).text().trim();
        console.log(`  Link ${i}: "${text}" -> ${href}`);
      });
    }
    
  } catch (error) {
    console.error('Error analyzing Matcha Kāru:', error.message);
  }

  // Analyze Sho-Cha structure  
  console.log('\n--- Sho-Cha Analysis ---');
  try {
    const response = await axios.get('https://www.sho-cha.com/teeshop', {
      timeout: 30000,
      headers: {
        'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      }
    });

    const $ = cheerio.load(response.data);
    
    // Look for product pattern
    const teeshopLinks = $('a[href*="/teeshop/"]');
    console.log(`Found ${teeshopLinks.length} teeshop links`);
    
    // Analyze first few teeshop links
    console.log('\nFirst 5 teeshop links analysis:');
    teeshopLinks.each((i, el) => {
      if (i < 5) {
        const linkEl = $(el);
        const href = linkEl.attr('href');
        const text = linkEl.text().trim();
        
        // Look at parent elements for product name
        const parent = linkEl.parent();
        const grandparent = parent.parent();
        
        console.log(`\nLink ${i + 1}: ${href}`);
        console.log(`  Link text: "${text}"`);
        console.log(`  Parent tag: ${parent.get(0)?.tagName} with text: "${parent.text().trim().substring(0, 50)}..."`);
        console.log(`  Grandparent tag: ${grandparent.get(0)?.tagName} with text: "${grandparent.text().trim().substring(0, 50)}..."`);
        
        // Look for H1 or other headers near this link
        const nearbyH1 = linkEl.closest('section, div, article').find('h1');
        if (nearbyH1.length > 0) {
          console.log(`  Nearby H1: "${nearbyH1.text().trim()}"`);
        }
      }
    });
    
    // Look for H1 elements that might contain product names
    console.log('\nH1 elements (potential product names):');
    $('h1').each((i, el) => {
      if (i < 10) {
        const text = $(el).text().trim();
        console.log(`  H1 ${i + 1}: "${text}"`);
      }
    });
    
  } catch (error) {
    console.error('Error analyzing Sho-Cha:', error.message);
  }
}

analyzeStructureDeep();
