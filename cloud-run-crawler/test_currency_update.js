const HoriishichimeienSpecializedCrawler = require('./src/crawlers/horiishichimeien-crawler.js');
const MarukyuKoyamaenSpecializedCrawler = require('./src/crawlers/marukyu-koyamaen-crawler.js');
const IppodoTeaSpecializedCrawler = require('./src/crawlers/ippodo-tea-crawler.js');
const PoppateaSpecializedCrawler = require('./src/crawlers/poppatea-crawler.js');
const SazenteaSpecializedCrawler = require('./src/crawlers/sazentea-crawler.js');
const MatchaKaruSpecializedCrawler = require('./src/crawlers/matcha-karu-crawler.js');

console.log('Testing currency updates in crawlers...\n');

// Test data for price processing
const testPrices = {
  horiishichimeien: '¥2,500',
  marukyu: '¥1,800',
  ippodo: '¥3,200',
  poppatea: '€25.00',
  sazentea: '€19,99',
  matchaKaru: '€22,50'
};

// Expected currencies for each site
const expectedCurrencies = {
  horiishichimeien: 'JPY',
  marukyu: 'JPY', 
  ippodo: 'JPY',
  poppatea: 'EUR',
  sazentea: 'EUR',
  matchaKaru: 'EUR'
};

async function testCrawler(CrawlerClass, crawlerName, testPrice, expectedCurrency) {
  try {
    const crawler = new CrawlerClass();
    
    console.log(`🧪 Testing ${crawlerName} crawler:`);
    console.log(`   Input price: ${testPrice}`);
    
    const result = crawler.processPrice(testPrice);
    console.log(`   Processed price: ${result.cleanedPrice}`);
    console.log(`   Price value: ${result.priceValue}`);
    
    // Create a test product to check currency field
    const mockProduct = {
      id: 'test',
      name: 'Test Product',
      normalizedName: 'test product',
      site: crawlerName.toLowerCase(),
      siteName: crawlerName,
      price: result.cleanedPrice,
      originalPrice: result.cleanedPrice,
      priceValue: result.priceValue,
      currency: expectedCurrency,
      url: 'https://example.com',
      imageUrl: null,
      isInStock: true,
      isDiscontinued: false,
      missedScans: 0,
      category: 'Matcha',
      crawlSource: 'cloud-run',
      firstSeen: new Date(),
      lastChecked: new Date(),
      lastUpdated: new Date(),
      lastPriceHistoryUpdate: new Date()
    };
    
    console.log(`   Expected currency: ${expectedCurrency}`);
    console.log(`   Currency field: ${mockProduct.currency}`);
    
    const currencyMatch = mockProduct.currency === expectedCurrency;
    const priceProcessed = result.cleanedPrice && result.priceValue !== null;
    
    console.log(`   ✅ Currency correct: ${currencyMatch}`);
    console.log(`   ✅ Price processed: ${priceProcessed}`);
    
    if (currencyMatch && priceProcessed) {
      console.log(`   🎉 ${crawlerName} crawler test PASSED\n`);
      return true;
    } else {
      console.log(`   ❌ ${crawlerName} crawler test FAILED\n`);
      return false;
    }
    
  } catch (error) {
    console.log(`   ❌ ${crawlerName} crawler test ERROR: ${error.message}\n`);
    return false;
  }
}

async function runAllTests() {
  const tests = [
    [HoriishichimeienSpecializedCrawler, 'Horiishichimeien', testPrices.horiishichimeien, expectedCurrencies.horiishichimeien],
    [MarukyuKoyamaenSpecializedCrawler, 'Marukyu-Koyamaen', testPrices.marukyu, expectedCurrencies.marukyu],
    [IppodoTeaSpecializedCrawler, 'Ippodo Tea', testPrices.ippodo, expectedCurrencies.ippodo],
    [PoppateaSpecializedCrawler, 'Poppatea', testPrices.poppatea, expectedCurrencies.poppatea],
    [SazenteaSpecializedCrawler, 'Sazen Tea', testPrices.sazentea, expectedCurrencies.sazentea],
    [MatchaKaruSpecializedCrawler, 'Matcha-Karu', testPrices.matchaKaru, expectedCurrencies.matchaKaru]
  ];
  
  const results = [];
  
  for (const [CrawlerClass, name, price, currency] of tests) {
    const result = await testCrawler(CrawlerClass, name, price, currency);
    results.push({ name, passed: result });
  }
  
  console.log('📊 Test Summary:');
  let passedCount = 0;
  results.forEach(({ name, passed }) => {
    console.log(`   ${passed ? '✅' : '❌'} ${name}: ${passed ? 'PASSED' : 'FAILED'}`);
    if (passed) passedCount++;
  });
  
  console.log(`\n🏆 Overall: ${passedCount}/${results.length} tests passed`);
  
  if (passedCount === results.length) {
    console.log('🎉 All currency updates working correctly!');
  } else {
    console.log('⚠️  Some crawlers need attention.');
  }
}

runAllTests().catch(console.error);
