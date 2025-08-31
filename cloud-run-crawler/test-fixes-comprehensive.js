const CrawlerService = require('./src/crawler-service');

async function testAllFixes() {
  const crawler = new CrawlerService();
  
  console.log('🧪 Testing all recent fixes...\n');

  // Test 1: Currency conversion for Horiishichimeien
  console.log('1. Testing Horiishichimeien JPY to EUR conversion:');
  const horiPrice1 = crawler.cleanPriceBySite('¥10,800', 'horiishichimeien');
  const horiPrice2 = crawler.cleanPriceBySite('¥648', 'horiishichimeien');
  console.log(`   ¥10,800 -> ${horiPrice1} (should be ~€70.20)`);
  console.log(`   ¥648 -> ${horiPrice2} (should be ~€4.21)\n`);

  // Test 2: Sho-Cha price parsing
  console.log('2. Testing Sho-Cha price parsing:');
  const shoChaPrice1 = crawler.cleanPriceBySite('5,00€', 'sho-cha');
  const shoChaPrice2 = crawler.cleanPriceBySite('24,00 €', 'sho-cha');
  console.log(`   5,00€ -> ${shoChaPrice1} (should be €5.00)`);
  console.log(`   24,00 € -> ${shoChaPrice2} (should be €24.00)\n`);

  // Test 3: Poppatea SEK to EUR conversion
  console.log('3. Testing Poppatea SEK to EUR conversion:');
  const poppatPrice1 = crawler.cleanPriceBySite('160 kr', 'poppatea');
  const poppatPrice2 = crawler.cleanPriceBySite('€12.50', 'poppatea');
  console.log(`   160 kr -> ${poppatPrice1} (should be ~€13.76)`);
  console.log(`   €12.50 -> ${poppatPrice2} (should be €12.50)\n`);

  // Test 4: Category detection for accessories
  console.log('4. Testing accessory category detection:');
  const categories = [
    { name: 'Matcha Schale Premium', expected: 'Accessories' },
    { name: 'Teeschale Traditional', expected: 'Accessories' },
    { name: 'Ceramic Bowl for Tea', expected: 'Accessories' },
    { name: 'Premium Matcha Powder', expected: 'Matcha' },
    { name: 'Tea Becher Modern', expected: 'Accessories' }
  ];
  
  categories.forEach(test => {
    const detected = crawler.detectCategory(test.name, 'test');
    const result = detected === test.expected ? '✅' : '❌';
    console.log(`   ${result} "${test.name}" -> ${detected} (expected: ${test.expected})`);
  });
  console.log();

  // Test 5: Currency parsing function
  console.log('5. Testing currency parsing:');
  const currencies = [
    { text: '$25.99', expected: { amount: 25.99, currency: 'USD' } },
    { text: '¥10,800', expected: { amount: 10800, currency: 'JPY' } },
    { text: '160 kr', expected: { amount: 160, currency: 'SEK' } },
    { text: '5,00€', expected: { amount: 5.00, currency: 'EUR' } },
    { text: 'CAD 19.99', expected: { amount: 19.99, currency: 'CAD' } }
  ];
  
  currencies.forEach(test => {
    const parsed = crawler.parsePriceAndCurrency(test.text);
    const amountMatch = Math.abs(parsed.amount - test.expected.amount) < 0.01;
    const currencyMatch = parsed.currency === test.expected.currency;
    const result = amountMatch && currencyMatch ? '✅' : '❌';
    console.log(`   ${result} "${test.text}" -> ${parsed.amount} ${parsed.currency} (expected: ${test.expected.amount} ${test.expected.currency})`);
  });
  console.log();

  // Test 6: Test EUR conversion
  console.log('6. Testing EUR conversion:');
  const conversions = [
    { amount: 25.99, from: 'USD', expected: 22.09 },
    { amount: 10800, from: 'JPY', expected: 70.20 },
    { amount: 160, from: 'SEK', expected: 13.76 },
    { amount: 19.99, from: 'CAD', expected: 12.59 }
  ];
  
  conversions.forEach(test => {
    const converted = crawler.convertToEURSync(test.amount, test.from);
    const match = Math.abs(converted - test.expected) < 1.0; // Allow 1 EUR difference
    const result = match ? '✅' : '❌';
    console.log(`   ${result} ${test.amount} ${test.from} -> €${converted.toFixed(2)} (expected: ~€${test.expected})`);
  });

  console.log('\n✨ All tests completed!');
}

// Test specific site crawling
async function testSiteCrawling() {
  console.log('\n🕷️ Testing specific site crawling...\n');
  
  const crawler = new CrawlerService();
  
  try {
    // Test only a few key sites to verify functionality
    const results = await crawler.crawlSites(['sho-cha', 'poppatea']);
    
    console.log('Crawling results:');
    Object.entries(results).forEach(([site, data]) => {
      console.log(`${site}: ${data.products?.length || 0} products, ${data.stockUpdates || 0} updates`);
      
      if (data.products && data.products.length > 0) {
        const sample = data.products[0];
        console.log(`  Sample: ${sample.name} - ${sample.price} (${sample.site})`);
      }
    });
  } catch (error) {
    console.error('Crawling test failed:', error.message);
  }
}

// Run tests
async function main() {
  try {
    await testAllFixes();
    // Uncomment to test actual crawling (takes longer)
    // await testSiteCrawling();
  } catch (error) {
    console.error('Test failed:', error);
  }
}

main();
