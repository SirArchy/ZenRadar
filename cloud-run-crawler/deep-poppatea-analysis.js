const axios = require('axios');
const cheerio = require('cheerio');

async function deepAnalyzePoppateaStructure() {
  console.log('🔍 Deep Analysis of Poppatea Collection Page\n');
  
  const url = 'https://poppatea.com/de-de/collections/all-teas';
  
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
    
    const $ = cheerio.load(response.data);
    
    console.log('📊 Detailed Collection Page Analysis\n');
    
    // Find all .card elements and analyze their content
    const cards = $('.card');
    console.log(`Found ${cards.length} .card elements\n`);
    
    cards.each((index, card) => {
      const $card = $(card);
      console.log(`🃏 Card ${index + 1}:`);
      
      // Look for any links
      const allLinks = $card.find('a');
      console.log(`  Links found: ${allLinks.length}`);
      allLinks.each((i, link) => {
        const href = $(link).attr('href');
        const text = $(link).text().trim();
        console.log(`    Link ${i + 1}: href="${href}" text="${text}"`);
      });
      
      // Look for any text content that might be product names
      const textContent = $card.text().trim();
      if (textContent.length > 0) {
        console.log(`  Text content: "${textContent.substring(0, 100)}..."`);
      }
      
      // Look for specific elements within the card
      const titleSelectors = ['h1', 'h2', 'h3', 'h4', 'h5', '.title', '.name', '.product-title', '.card-title', '.card__title'];
      for (const selector of titleSelectors) {
        const elements = $card.find(selector);
        if (elements.length > 0) {
          console.log(`  Found ${selector}: "${elements.first().text().trim()}"`);
        }
      }
      
      // Look for price elements
      const priceSelectors = ['.price', '.money', '.cost', '.amount'];
      for (const selector of priceSelectors) {
        const elements = $card.find(selector);
        if (elements.length > 0) {
          console.log(`  Found ${selector}: "${elements.first().text().trim()}"`);
        }
      }
      
      // Look for images
      const images = $card.find('img');
      if (images.length > 0) {
        const src = images.first().attr('src');
        const alt = images.first().attr('alt');
        console.log(`  Image: src="${src}" alt="${alt}"`);
      }
      
      // Show full HTML structure for first few cards
      if (index < 3) {
        console.log(`  HTML Structure:`);
        console.log(`  ${$card.html().substring(0, 500)}...`);
      }
      
      console.log('');
    });
    
    // Also look for other potential product containers
    console.log('\n🔍 Alternative Product Container Search:');
    
    const alternativeSelectors = [
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
      '.product-wrap',
      'article[data-product]',
      '.item',
      '.product__card',
      '.card--product'
    ];
    
    for (const selector of alternativeSelectors) {
      const elements = $(selector);
      if (elements.length > 0) {
        console.log(`✅ ${selector}: ${elements.length} elements found`);
        
        const firstElement = elements.first();
        const links = firstElement.find('a[href*="product"]');
        const titles = firstElement.find('h1, h2, h3, h4, .title, .name, .product-title, .card-title');
        const prices = firstElement.find('.price, .money, .cost, .amount');
        
        if (links.length > 0 || titles.length > 0) {
          console.log(`  🎯 PROMISING: Links: ${links.length}, Titles: ${titles.length}, Prices: ${prices.length}`);
          if (links.length > 0) {
            console.log(`    Sample link: ${links.first().attr('href')}`);
          }
          if (titles.length > 0) {
            console.log(`    Sample title: "${titles.first().text().trim()}"`);
          }
        }
      }
    }
    
    // Look for JavaScript-rendered content indicators
    console.log('\n🔍 JavaScript Content Analysis:');
    const scriptTags = $('script');
    let productDataFound = false;
    
    scriptTags.each((i, script) => {
      const scriptContent = $(script).html();
      if (scriptContent && scriptContent.includes('products')) {
        console.log(`✅ Product data found in script tag ${i + 1}`);
        productDataFound = true;
        
        // Look for specific patterns
        if (scriptContent.includes('window.collection')) {
          console.log('  - window.collection found');
        }
        if (scriptContent.includes('products:')) {
          console.log('  - products array found');
        }
      }
    });
    
    if (!productDataFound) {
      console.log('❌ No obvious product data in JavaScript');
    }
    
  } catch (error) {
    console.log(`❌ Failed: ${error.message}`);
  }
  
  console.log('\n✨ Deep Analysis Complete!');
}

if (require.main === module) {
  deepAnalyzePoppateaStructure().catch(console.error);
}
