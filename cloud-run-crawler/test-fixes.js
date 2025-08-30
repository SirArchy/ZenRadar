const axios = require('axios');
const cheerio = require('cheerio');

// Updated configurations based on analysis
const matchaKaruConfig = {
  name: 'Matcha Kāru',
  baseUrl: 'https://matcha-karu.com',
  categoryUrl: 'https://matcha-karu.com/collections/matcha-tee',
  productSelector: '.product-item',
  nameSelector: 'h3 a, .product-item__title a, .product-title a, a[href*="/products/"]',
  priceSelector: '.price, .price__current, .price-item',
  stockSelector: '.product-form, .add-to-cart:not(.disabled)', 
  linkSelector: 'a[href*="/products/"]',
  imageSelector: '.product-item__image img, .product-image img, img[src*="products/"]',
  stockKeywords: ['add to cart', 'in den warenkorb', 'kaufen', 'angebotspreis'],
  outOfStockKeywords: ['ausverkauft', 'nicht verfügbar', 'sold out']
};

const shoChaConfig = {
  name: 'Sho-Cha',
  baseUrl: 'https://www.sho-cha.com',
  categoryUrl: 'https://www.sho-cha.com/teeshop',
  productSelector: 'h1, .product-item, .shop-item',
  nameSelector: 'h1, a[href*="/teeshop/"], .product-title, .item-title', 
  priceSelector: '.price, .cost, .amount, .money',
  stockSelector: '.add-to-cart, .cart-button, .shop-button',
  linkSelector: 'a[href*="/teeshop/"]',
  imageSelector: '.product-image img, .item-image img, img[src*="product"], img[src*="tea"], img[src*="matcha"]',
  stockKeywords: ['add to cart', 'kaufen', 'in den warenkorb', 'verfügbar'],
  outOfStockKeywords: ['ausverkauft', 'sold out', 'nicht verfügbar']
};

function extractText(element, selectors) {
  const selectorList = selectors.split(',').map(s => s.trim());
  
  for (const selector of selectorList) {
    const found = element.find(selector).first();
    if (found.length > 0) {
      let text = found.text().trim();
      if (text) return text;
    }
  }
  return '';
}

function extractLink(element, selectors, baseUrl) {
  const selectorList = selectors.split(',').map(s => s.trim());
  
  for (const selector of selectorList) {
    const found = element.find(selector).first();
    if (found.length > 0) {
      const href = found.attr('href');
      if (href) {
        if (href.startsWith('/')) {
          return baseUrl + href;
        }
        return href;
      }
    }
  }
  return '';
}

async function testUpdatedConfigs() {
  console.log('=== Testing Updated Matcha Kāru Config ===');
  try {
    const response = await axios.get(matchaKaruConfig.categoryUrl, {
      timeout: 30000,
      headers: {
        'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      }
    });

    const $ = cheerio.load(response.data);
    const productElements = $(matchaKaruConfig.productSelector);
    
    console.log(`Found ${productElements.length} product containers`);
    
    let extractedProducts = 0;
    productElements.each((i, element) => {
      if (i < 3) { // Test first 3 products
        const productElement = $(element);
        
        const name = extractText(productElement, matchaKaruConfig.nameSelector);
        const price = extractText(productElement, matchaKaruConfig.priceSelector);
        const link = extractLink(productElement, matchaKaruConfig.linkSelector, matchaKaruConfig.baseUrl);
        
        console.log(`\nProduct ${i + 1}:`);
        console.log(`  Name: "${name}"`);
        console.log(`  Price: "${price}"`);
        console.log(`  Link: "${link}"`);
        
        if (name && link) extractedProducts++;
      }
    });
    
    console.log(`\nSuccessfully extracted ${extractedProducts} products from Matcha Kāru`);
    
  } catch (error) {
    console.error('Error testing Matcha Kāru:', error.message);
  }

  console.log('\n=== Testing Updated Sho-Cha Config ===');
  try {
    const response = await axios.get(shoChaConfig.categoryUrl, {
      timeout: 30000,
      headers: {
        'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      }
    });

    const $ = cheerio.load(response.data);
    
    // Since Sho-Cha structure is different, let's test extracting products from H1 elements and teeshop links
    const h1Elements = $('h1');
    const teeshopLinks = $('a[href*="/teeshop/"]');
    
    console.log(`Found ${h1Elements.length} H1 elements (potential products)`);
    console.log(`Found ${teeshopLinks.length} teeshop links`);
    
    let extractedProducts = 0;
    
    // Test extracting from teeshop links
    teeshopLinks.each((i, element) => {
      if (i < 5) { // Test first 5 links
        const linkElement = $(element);
        const href = linkElement.attr('href');
        const text = linkElement.text().trim();
        
        console.log(`\nTeeshop Link ${i + 1}:`);
        console.log(`  Text: "${text}"`);
        console.log(`  Href: "${href}"`);
        
        if (text && href) extractedProducts++;
      }
    });
    
    console.log(`\nSuccessfully extracted ${extractedProducts} potential products from Sho-Cha`);
    
  } catch (error) {
    console.error('Error testing Sho-Cha:', error.message);
  }

  console.log('\n=== Testing Image URL Fix ===');
  const testImageUrl = 'https://horiishichimeien.com/cdn/shop/products/MG_8632_{width}x.jpg';
  const fixedImageUrl = testImageUrl.replace(/_{width}x/, '');
  
  console.log('Original URL:', testImageUrl);
  console.log('Fixed URL:', fixedImageUrl);
  
  try {
    const response = await axios.head(fixedImageUrl, { timeout: 10000 });
    console.log('Fixed image URL status:', response.status, '✅');
  } catch (error) {
    console.log('Fixed image URL failed:', error.response?.status || error.code, '❌');
  }
}

testUpdatedConfigs();
