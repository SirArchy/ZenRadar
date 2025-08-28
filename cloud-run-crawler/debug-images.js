const axios = require('axios');
const cheerio = require('cheerio');

// Import the site configurations
const siteConfigs = {
  "yoshien": {
    "url": "https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha?currency=USD",
    "productSelector": ".product",
    "titleSelector": ".product-name, .item-name, h3",
    "linkSelector": "a, .item-link",
    "priceSelector": ".price, .item-price, .cost",
    "stockSelector": ".cart-form button:not([disabled]), .add-to-cart:not(.disabled)",
    "imageSelector": ".product-image img, .item-image img, img[src*=\"product\"]"
  },
  "matcha-karu": {
    "url": "https://matcha-karu.com/collections/matcha-powder",
    "productSelector": ".grid__item .card",
    "titleSelector": ".card__heading a",
    "linkSelector": ".card__heading a",
    "priceSelector": ".price",
    "stockSelector": ".card__badge",
    "imageSelector": ".card__media img"
  },
  "sho-cha": {
    "url": "https://global.sho-cha.jp/collections/matcha",
    "productSelector": ".grid__item",
    "titleSelector": ".card__heading",
    "linkSelector": ".card__heading a",
    "priceSelector": ".price",
    "stockSelector": ".card__badge",
    "imageSelector": ".card__media img"
  },
  "enjoyemeri": {
    "url": "https://enjoyemeri.com/collections/matcha",
    "productSelector": ".product-card",
    "titleSelector": "h3, .product-title",
    "linkSelector": "a",
    "priceSelector": ".price",
    "stockSelector": ".price",
    "imageSelector": ".product-card__image img, .product-image img"
  },
  "poppatea": {
    "url": "https://poppatea.com/collections/matcha",
    "productSelector": ".grid__item .card",
    "titleSelector": ".card__heading",
    "linkSelector": ".card__heading a",
    "priceSelector": ".price",
    "stockSelector": ".card__badge",
    "imageSelector": ".card__media img"
  },
  "horiishichimeien": {
    "url": "https://horiishichimeien.com/en/collections/all?selected=%E6%8A%B9%E8%8C%B6",
    "productSelector": ".grid__item",
    "titleSelector": "a[href*=\"/products/\"] span.visually-hidden, .card__heading",
    "linkSelector": "a[href*=\"/products/\"]",
    "priceSelector": ".price, .price__regular, .money, .price-item",
    "stockSelector": ".product-form__buttons, .product-form, form[action=\"/cart/add\"], button[name=\"add\"]",
    "imageSelector": ".grid-view-item__image, .lazyload, img[src*=\"products/\"]"
  }
};

async function testImageExtraction(siteName, config) {
  console.log(`\n=== Testing ${siteName} ===`);
  try {
    const response = await axios.get(config.url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      },
      timeout: 30000
    });

    const $ = cheerio.load(response.data);
    const products = $(config.productSelector);
    
    console.log(`Found ${products.length} products`);
    
    if (products.length > 0) {
      const firstProduct = products.first();
      console.log(`\nFirst product analysis:`);
      
      // Test title
      const title = firstProduct.find(config.titleSelector).text().trim();
      console.log(`Title: "${title}"`);
      
      // Test image extraction
      console.log(`\nTesting image selector: "${config.imageSelector}"`);
      const images = firstProduct.find(config.imageSelector);
      console.log(`Found ${images.length} images with main selector`);
      
      images.each((i, img) => {
        const src = $(img).attr('src') || $(img).attr('data-src') || $(img).attr('data-lazy');
        const alt = $(img).attr('alt');
        console.log(`  Image ${i}: src="${src}", alt="${alt}"`);
      });
      
      // Test alternative selectors
      console.log(`\nTesting alternative selectors:`);
      const allImages = firstProduct.find('img');
      console.log(`Total images in product: ${allImages.length}`);
      
      allImages.each((i, img) => {
        const src = $(img).attr('src') || $(img).attr('data-src') || $(img).attr('data-lazy');
        const alt = $(img).attr('alt') || 'no alt';
        const classes = $(img).attr('class') || 'no class';
        console.log(`  All img ${i}: src="${src}", alt="${alt}", class="${classes}"`);
      });
      
      // Print product HTML for debugging
      console.log(`\nFirst product HTML (truncated):`);
      console.log(firstProduct.html().substring(0, 500) + '...');
    } else {
      console.log('No products found - checking page structure...');
      console.log('Available selectors that might match:');
      
      // Check for common product selectors
      const commonSelectors = [
        '.product', '.product-item', '.grid-item', '.card', 
        '[data-product]', '.product-card', '.item'
      ];
      
      commonSelectors.forEach(selector => {
        const count = $(selector).length;
        if (count > 0) {
          console.log(`  ${selector}: ${count} elements`);
        }
      });
    }
    
  } catch (error) {
    console.error(`Error testing ${siteName}:`, error.message);
  }
}

async function runTests() {
  console.log('Testing image extraction for problematic sites...\n');
  
  const problematicSites = ['yoshien', 'matcha-karu', 'sho-cha', 'enjoyemeri', 'poppatea', 'horiishichimeien'];
  
  for (const siteName of problematicSites) {
    if (siteConfigs[siteName]) {
      await testImageExtraction(siteName, siteConfigs[siteName]);
      await new Promise(resolve => setTimeout(resolve, 2000)); // Wait between requests
    }
  }
}

runTests().catch(console.error);
