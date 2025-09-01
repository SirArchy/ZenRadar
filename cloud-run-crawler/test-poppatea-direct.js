const PoppateaSpecializedCrawler = require('./src/crawlers/poppatea-crawler');

// Mock logger for testing
const mockLogger = {
  info: (msg, meta) => console.log(`[INFO] ${msg}`, meta || ''),
  warn: (msg, meta) => console.log(`[WARN] ${msg}`, meta || ''),
  error: (msg, meta) => console.log(`[ERROR] ${msg}`, meta || '')
};

async function testPoppateaCrawlerDirect() {
  console.log('🧪 Testing Updated Poppatea Crawler (Direct Test)\n');
  
  const crawler = new PoppateaSpecializedCrawler(mockLogger);
  
  try {
    const startTime = Date.now();
    const result = await crawler.crawl('https://poppatea.com/de-de/collections/all-teas');
    const duration = Date.now() - startTime;
    
    console.log(`⏱️  Crawl completed in ${duration}ms`);
    console.log(`📦 Products found: ${result.products.length}`);
    console.log(`🚨 Errors: ${result.errors ? result.errors.length : 0}`);
    
    // Show sample products
    if (result.products.length > 0) {
      console.log('\n📋 Sample Products:');
      result.products.slice(0, 5).forEach((product, index) => {
        console.log(`  ${index + 1}. ${product.name}`);
        console.log(`     Price: ${product.price} (€${product.priceValue})`);
        console.log(`     URL: ${product.url}`);
        console.log(`     In Stock: ${product.isInStock}`);
        console.log(`     Category: ${product.category}`);
        if (product.variantId) {
          console.log(`     Variant ID: ${product.variantId}`);
        }
        console.log('');
      });
    }
    
    // Validate key fields
    const validProducts = result.products.filter(p => 
      p.name && p.name.length > 2 && 
      p.url && 
      p.priceValue !== null && p.priceValue > 0
    );
    
    const validationRate = validProducts.length / result.products.length;
    console.log(`✅ Validation Rate: ${(validationRate * 100).toFixed(1)}% (${validProducts.length}/${result.products.length})`);
    
    if (validationRate >= 0.8) {
      console.log('🎉 POPPATEA CRAWLER WORKING CORRECTLY!');
    } else if (validationRate >= 0.5) {
      console.log('⚠️  Poppatea crawler partially working - needs minor adjustments');
    } else {
      console.log('❌ Poppatea crawler needs significant debugging');
    }
    
  } catch (error) {
    console.log(`❌ Error testing Poppatea crawler:`, error.message);
    console.log(error.stack);
  }
}

testPoppateaCrawlerDirect().catch(console.error);
