const axios = require('axios');
const cheerio = require('cheerio');

async function testYoshienCrawler() {
  console.log('🧪 Testing Yoshien crawler...');
  
  try {
    // Test the main matcha page
    const url = 'https://www.yoshien.com/matcha';
    console.log(`📡 Fetching: ${url}`);
    
    const response = await axios.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1'
      },
      timeout: 30000
    });

    console.log(`✅ Response status: ${response.status}`);
    console.log(`📄 Response length: ${response.data.length} characters`);
    
    const $ = cheerio.load(response.data);
    
    // Test different possible selectors
    const testSelectors = [
      '.product-item',
      '.product-card', 
      '.product',
      '.grid-item',
      '[data-product]',
      'article',
      '.product-wrap',
      '.product-container',
      '.item',
      '.shop-item'
    ];
    
    console.log('\n🔍 Testing product selectors:');
    testSelectors.forEach(selector => {
      const elements = $(selector);
      console.log(`  ${selector}: ${elements.length} elements found`);
      
      if (elements.length > 0 && elements.length < 20) {
        console.log(`    First element classes: ${elements.first().attr('class')}`);
        console.log(`    First element HTML preview: ${elements.first().html()?.substring(0, 200)}...`);
      }
    });
    
    // Check for any links that might lead to products
    const productLinks = $('a[href*="/product"], a[href*="matcha"]');
    console.log(`\n🔗 Found ${productLinks.length} potential product links`);
    
    productLinks.slice(0, 10).each((i, el) => {
      const link = $(el).attr('href');
      const text = $(el).text().trim();
      console.log(`  ${i + 1}. ${link} - "${text}"`);
    });
    
    // Check page title and basic structure
    console.log(`\n📄 Page title: "${$('title').text()}"`);
    console.log(`📄 H1 elements: ${$('h1').length}`);
    console.log(`📄 H2 elements: ${$('h2').length}`);
    console.log(`📄 H3 elements: ${$('h3').length}`);
    
    // Look for any e-commerce indicators
    const priceElements = $('.price, .money, [data-price], .product-price');
    console.log(`💰 Price elements found: ${priceElements.length}`);
    
    if (priceElements.length > 0) {
      console.log(`💰 Sample price elements with context:`);
      priceElements.slice(0, 5).each((i, el) => {
        const $el = $(el);
        const text = $el.text().trim();
        const parent = $el.parent();
        const grandparent = parent.parent();
        
        console.log(`  ${i + 1}. "${text}" - classes: ${$el.attr('class')}`);
        console.log(`     Parent: <${parent.prop('tagName')}> class="${parent.attr('class') || 'none'}"`);
        console.log(`     Grandparent: <${grandparent.prop('tagName')}> class="${grandparent.attr('class') || 'none'}"`);
        console.log(`     Context HTML: ${grandparent.html()?.substring(0, 300)}...`);
        console.log(`     ---`);
      });
    }
    
    // Check if this might be a category page vs product listing
    const categoryLinks = $('a[href*="/collections/"], a[href*="/category/"], a[href*="/categories/"]');
    console.log(`📂 Category links found: ${categoryLinks.length}`);
    
    if (categoryLinks.length > 0) {
      console.log('\n📂 Possible category structure:');
      categoryLinks.slice(0, 5).each((i, el) => {
        const link = $(el).attr('href');
        const text = $(el).text().trim();
        console.log(`  ${i + 1}. ${link} - "${text}"`);
      });
    }

    // Check for Shopify indicators
    const shopifyIndicators = $('script[src*="shopify"], [data-shopify], .shopify-section, #shopify-section');
    console.log(`🛒 Shopify indicators: ${shopifyIndicators.length}`);

    // Look for product containers by working backwards from price elements
    console.log(`\n🏷️ Looking for product containers from price elements:`);
    
    // Try level 7 which should be the full product tile
    const productTiles = $('.price').parent().parent().parent().parent().parent().parent().parent();
    console.log(`\nLevel 7 up from .price: Found ${productTiles.length} containers`);
    
    if (productTiles.length > 0) {
      productTiles.slice(0, 3).each((i, el) => {
        const $el = $(el);
        const classes = $el.attr('class');
        const tagName = $el.prop('tagName');
        console.log(`\n  ${i + 1}. <${tagName}> class="${classes || 'none'}"`);
        
        // Look for product name
        const nameSelectors = [
          'h1', 'h2', 'h3', 'h4', 
          '.product-name', '.title', '.cs-product-tile__title',
          'a[title]', '.name', 'a.product-item-link'
        ];
        let productName = '';
        for (const selector of nameSelectors) {
          const nameEl = $el.find(selector).first();
          if (nameEl.length > 0) {
            const text = nameEl.text().trim();
            const title = nameEl.attr('title');
            if ((text && text.length > 0 && text.length < 200) || (title && title.length < 200)) {
              productName = text || title;
              console.log(`    Name (${selector}): "${productName}"`);
              break;
            }
          }
        }
        
        // Look for product links
        const links = $el.find('a[href*=".html"], a[href*="matcha"]');
        if (links.length > 0) {
          const href = links.first().attr('href');
          console.log(`    Link: ${href}`);
        }
        
        // Look for images
        const images = $el.find('img');
        if (images.length > 0) {
          const imgSrc = images.first().attr('src') || images.first().attr('data-src');
          console.log(`    Image: ${imgSrc?.substring(0, 100)}...`);
        }
        
        // Look for price with data attributes
        const priceEl = $el.find('[data-price-amount]').first();
        if (priceEl.length > 0) {
          const priceAmount = priceEl.attr('data-price-amount');
          const priceText = $el.find('.price').first().text().trim();
          console.log(`    Price: "${priceText}" (amount: ${priceAmount})`);
        }
      });
    }
    
    // Also check if there's a common container class we can use directly
    console.log(`\n🔍 Looking for common product tile classes:`);
    const tileSelectors = [
      '.cs-product-tile',
      '.product-item',
      '.product-tile',
      '.item-container'
    ];
    
    tileSelectors.forEach(selector => {
      const elements = $(selector);
      console.log(`  ${selector}: ${elements.length} elements found`);
      if (elements.length > 0 && elements.length < 100) {
        console.log(`    First element: <${elements.first().prop('tagName')}> class="${elements.first().attr('class')}"`);
      }
    });
    
  } catch (error) {
    console.error('❌ Error testing Yoshien crawler:', error.message);
    
    if (error.response) {
      console.error(`   Status: ${error.response.status}`);
      console.error(`   Status text: ${error.response.statusText}`);
    }

    if (error.code === 'ENOTFOUND') {
      console.error('   DNS resolution failed - domain might not exist or be accessible');
    }
  }
}

// Run the test
testYoshienCrawler();
