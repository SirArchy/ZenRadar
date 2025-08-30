const CrawlerService = require('./src/crawler-service');

// Mock dependencies for testing
const mockFirestore = {
  collection: () => ({
    doc: () => ({
      get: () => Promise.resolve({
        exists: false,
        data: () => ({})
      }),
      set: () => Promise.resolve(),
      update: () => Promise.resolve()
    }),
    where: () => ({
      get: () => Promise.resolve({
        empty: true,
        docs: []
      })
    })
  })
};

const mockLogger = {
  info: console.log,
  error: console.error,
  warn: console.warn
};

async function testSiteAccess() {
  // Create crawler without Firebase dependencies
  const crawler = {
    siteConfigs: {
      'matcha-karu': {
        name: 'Matcha Kāru',
        baseUrl: 'https://matcha-karu.com',
        categoryUrl: 'https://matcha-karu.com/collections/all',
        productSelector: '.product-item',
        nameSelector: 'h3, .product-title, [data-product-title]',
        priceSelector: '.price',
        stockSelector: '.add-to-cart, .cart-button',
        linkSelector: 'a',
        imageSelector: 'img',
        stockKeywords: ['add to cart', 'in den warenkorb', 'kaufen'],
        outOfStockKeywords: ['ausverkauft', 'nicht verfügbar', 'sold out']
      },
      'poppatea': {
        name: 'Poppatea',
        baseUrl: 'https://poppatea.com',
        categoryUrl: 'https://poppatea.com/collections/all',
        productSelector: '.card',
        nameSelector: 'h3, .card-title, [data-product-title]',
        priceSelector: '.price',
        stockSelector: '.add-to-cart, .cart-button',
        linkSelector: 'a',
        imageSelector: 'img',
        stockKeywords: ['add to cart', 'lägg i varukorg', 'köp'],
        outOfStockKeywords: ['slutsåld', 'ej i lager', 'sold out', 'notify me']
      },
      'horiishichimeien': {
        name: 'Horiishichimeien',
        baseUrl: 'https://horiishichimeien.com',
        categoryUrl: 'https://horiishichimeien.com/en/collections/all?selected=%E6%8A%B9%E8%8C%B6',
        productSelector: '.grid__item',
        nameSelector: 'a[href*="/products/"] span.visually-hidden, .card__heading',
        priceSelector: '.price__regular .money, .price .money, .price-item--regular',
        stockSelector: '.product-form__buttons, .product-form, form[action="/cart/add"], button[name="add"]',
        linkSelector: 'a[href*="/products/"]',
        imageSelector: '.grid-view-item__image, .lazyload, img[src*="products/"]',
        stockKeywords: ['add to cart', 'buy now', 'purchase', 'add to bag', 'カートに入れる'],
        outOfStockKeywords: ['sold out', 'unavailable', '売り切れ', 'out of stock']
      }
    }
  };
  
  // Test the missing sites
  const sitesToTest = ['matcha-karu', 'sho-cha', 'poppatea', 'horiishichimeien'];
  
  for (const siteKey of sitesToTest) {
    const config = crawler.siteConfigs[siteKey];
    if (!config) {
      console.log(`❌ ${siteKey}: Configuration not found`);
      continue;
    }
    
    console.log(`\n🧪 Testing ${siteKey} (${config.name})`);
    console.log(`📍 URL: ${config.categoryUrl}`);
    
    try {
      const axios = require('axios');
      const response = await axios.get(config.categoryUrl, {
        timeout: 10000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
      });
      
      console.log(`✅ ${siteKey}: Accessible (Status: ${response.status})`);
      console.log(`📊 Content Length: ${response.data.length} characters`);
      
      // Quick check for expected selectors
      const cheerio = require('cheerio');
      const $ = cheerio.load(response.data);
      
      const products = $(config.productSelector);
      console.log(`🛍️  Found ${products.length} potential products`);
      
      if (products.length > 0) {
        const firstProduct = products.first();
        const name = firstProduct.find(config.nameSelector).text().trim();
        const price = firstProduct.find(config.priceSelector).text().trim();
        console.log(`📝 Sample product: "${name}" - Price: "${price}"`);
      }
      
    } catch (error) {
      console.log(`❌ ${siteKey}: Error accessing site`);
      console.log(`🚨 Error: ${error.message}`);
      if (error.response) {
        console.log(`📊 Status: ${error.response.status}`);
      }
    }
  }
}

// Test site configurations
console.log('🔍 Testing Missing Sites Accessibility\n');
testSiteAccess().catch(console.error);
