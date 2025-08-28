const CrawlerService = require('./src/crawler-service');

async function testPoppatea() {
  console.log('Testing Poppatea with enhanced crawler...');
  
  const crawler = new CrawlerService();
  
  try {
    // Test the full extraction process
    const products = await crawler.extractProducts('poppatea');
    
    console.log(`\nExtracted ${products.length} products:`);
    
    // Show first 5 products
    products.slice(0, 5).forEach((product, index) => {
      console.log(`\nProduct ${index + 1}:`);
      console.log(`  Name: ${product.name}`);
      console.log(`  Price: ${product.price}`);
      console.log(`  Price Value: ${product.priceValue}`);
      console.log(`  Currency: ${product.currency}`);
      console.log(`  In Stock: ${product.isInStock}`);
      console.log(`  URL: ${product.url}`);
      if (product.variantId) {
        console.log(`  Variant ID: ${product.variantId}`);
      }
    });
    
    // Summary
    const withPrices = products.filter(p => p.priceValue > 0);
    const inStock = products.filter(p => p.isInStock);
    
    console.log(`\nSummary:`);
    console.log(`  Total products: ${products.length}`);
    console.log(`  With prices: ${withPrices.length}`);
    console.log(`  In stock: ${inStock.length}`);
    
    if (withPrices.length > 0) {
      const prices = withPrices.map(p => p.priceValue);
      console.log(`  Price range: €${Math.min(...prices).toFixed(2)} - €${Math.max(...prices).toFixed(2)}`);
    }
    
  } catch (error) {
    console.error('Error testing Poppatea:', error);
  }
}

testPoppatea();
