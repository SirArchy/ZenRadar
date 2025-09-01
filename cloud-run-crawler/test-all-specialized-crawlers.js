const axios = require('axios');
const SiteCrawlerFactory = require('./src/crawlers/site-crawler-factory');

// Mock logger for testing
const mockLogger = {
  info: (msg, meta) => console.log(`[INFO] ${msg}`, meta || ''),
  warn: (msg, meta) => console.log(`[WARN] ${msg}`, meta || ''),
  error: (msg, meta) => console.log(`[ERROR] ${msg}`, meta || '')
};

async function testAllSpecializedCrawlers() {
  console.log('🧪 Testing All Specialized Crawlers\n');
  
  const sites = [
    {
      key: 'sho-cha',
      name: 'Sho-Cha (German Tea Site)',
      url: 'https://sho-cha.de/collections/matcha-pulver-bio'
    },
    {
      key: 'poppatea',
      name: 'Poppatea (Swedish Shopify)',
      url: 'https://poppatea.se/collections/matcha'
    },
    {
      key: 'horiishichimeien',
      name: 'Horiishichimeien (Japanese Shopify)',
      url: 'https://horiishichimeien.com/collections/all'
    },
    {
      key: 'matcha-karu',
      name: 'Matcha Kāru (German Site)',
      url: 'https://matcha-karu.com/collections/matcha-tee'
    },
    {
      key: 'marukyu-koyamaen',
      name: 'Marukyu-Koyamaen (Japanese Site)',
      url: 'https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha'
    },
    {
      key: 'ippodo-tea',
      name: 'Ippodo Tea (International Shopify)',
      url: 'https://global.ippodo-tea.co.jp/collections/matcha'
    },
    {
      key: 'sazentea',
      name: 'Sazentea (German/European Site)',
      url: 'https://sazentea.de/collections/matcha'
    }
  ];

  for (const site of sites) {
    console.log(`\n📊 Testing ${site.name} (${site.key})`);
    console.log(`🔗 URL: ${site.url}`);
    
    try {
      // Check if specialized crawler exists
      const crawler = SiteCrawlerFactory.getCrawler(site.key, mockLogger);
      
      if (!crawler) {
        console.log(`❌ No specialized crawler found for ${site.key}`);
        continue;
      }
      
      console.log(`✅ Specialized crawler found for ${site.key}`);
      
      // Test the crawler with a limited crawl
      const startTime = Date.now();
      const result = await crawler.crawl(site.url, { maxProducts: 5 });
      const duration = Date.now() - startTime;
      
      console.log(`⏱️  Crawl completed in ${duration}ms`);
      console.log(`📦 Products found: ${result.products.length}`);
      console.log(`🚨 Errors: ${result.errors ? result.errors.length : 0}`);
      
      // Show sample products
      if (result.products.length > 0) {
        console.log('\n📋 Sample Products:');
        result.products.slice(0, 3).forEach((product, index) => {
          console.log(`  ${index + 1}. ${product.name}`);
          console.log(`     Price: ${product.price} (€${product.priceValue})`);
          console.log(`     URL: ${product.url}`);
          console.log(`     In Stock: ${product.isInStock}`);
          console.log(`     Category: ${product.category}`);
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
      
      if (validationRate < 0.5) {
        console.log(`⚠️  Low validation rate for ${site.key} - needs attention`);
      }
      
    } catch (error) {
      console.log(`❌ Error testing ${site.key}:`, error.message);
      
      // Check if it's a network issue or crawler issue
      if (error.code === 'ENOTFOUND' || error.code === 'ECONNREFUSED') {
        console.log(`🌐 Network issue - site may be down or blocking requests`);
      } else if (error.message.includes('timeout')) {
        console.log(`⏱️  Timeout issue - site may be slow or blocking requests`);
      } else {
        console.log(`🐛 Crawler logic issue - needs debugging`);
      }
    }
    
    console.log('─'.repeat(80));
  }
  
  // Summary
  console.log('\n📊 Specialized Crawler Summary:');
  console.log(`Total specialized sites: ${sites.length}`);
  console.log(`Sites with crawlers: ${SiteCrawlerFactory.getSpecializedSites().length}`);
  console.log('\nSpecialized Sites List:');
  SiteCrawlerFactory.getSpecializedSites().forEach((siteKey, index) => {
    console.log(`  ${index + 1}. ${siteKey}`);
  });
}

// Test currency conversion accuracy
async function testCurrencyConversions() {
  console.log('\n💱 Testing Currency Conversions\n');
  
  const testPrices = [
    { original: '¥648', site: 'horiishichimeien', expected: '€3.76' },
    { original: '¥1000', site: 'marukyu-koyamaen', expected: '€5.80' },
    { original: '$25.00', site: 'ippodo-tea', expected: '€23.00' },
    { original: '19,00 €', site: 'sho-cha', expected: '€19.00' },
    { original: '129 kr', site: 'poppatea', expected: '€11.40' }
  ];
  
  for (const test of testPrices) {
    console.log(`🔄 Testing ${test.site}: ${test.original} → ${test.expected}`);
    
    try {
      const crawler = SiteCrawlerFactory.getCrawler(test.site, mockLogger);
      if (crawler && crawler.processPrice) {
        const result = crawler.processPrice(test.original);
        console.log(`   Result: ${result.cleanedPrice} (€${result.priceValue})`);
        
        const expectedValue = parseFloat(test.expected.replace('€', ''));
        const actualValue = result.priceValue;
        const difference = Math.abs(expectedValue - actualValue);
        const tolerance = expectedValue * 0.1; // 10% tolerance
        
        if (difference <= tolerance) {
          console.log(`   ✅ Conversion accurate (within 10% tolerance)`);
        } else {
          console.log(`   ⚠️  Conversion may need adjustment (diff: €${difference.toFixed(2)})`);
        }
      }
    } catch (error) {
      console.log(`   ❌ Error: ${error.message}`);
    }
    console.log('');
  }
}

// Run all tests
async function main() {
  console.log('🚀 Starting Comprehensive Specialized Crawler Tests\n');
  
  await testAllSpecializedCrawlers();
  await testCurrencyConversions();
  
  console.log('\n✨ Testing Complete!');
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = { testAllSpecializedCrawlers, testCurrencyConversions };
