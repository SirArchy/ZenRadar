const PriceUtils = require('./src/utils/price-utils');

/**
 * Test the fixed exchange rate
 */
function testFixedExchangeRate() {
  console.log('🧪 Testing Fixed Horiishichimeien Exchange Rate');
  console.log('============================================\n');

  const priceUtils = new PriceUtils();
  
  // Test the specific case
  const testPrice = 648; // JPY
  const convertedPrice = priceUtils.convertToEUR(testPrice, 'JPY');
  
  console.log(`💴 Original price: ¥${testPrice}`);
  console.log(`📊 Updated rate: 0.0058 EUR per JPY`);
  console.log(`💰 New conversion: €${convertedPrice}`);
  console.log(`🎯 Expected: €3.76`);
  console.log(`✅ Match: ${Math.abs(convertedPrice - 3.76) < 0.05 ? 'YES' : 'NO'}`);
  
  console.log('\n' + '='.repeat(50));
  
  // Test a few other Horiishichimeien prices we found
  const testPrices = [
    { jpy: 540, name: 'Hojicha Oyatoko no hojicha' },
    { jpy: 864, name: 'Tea bag Hojicha' },
    { jpy: 972, name: 'Hojicha powder' },
    { jpy: 1080, name: 'Hojicha Uji-chashi hojicha' },
    { jpy: 2484, name: 'Matcha Uji Mukashi' },
    { jpy: 3240, name: 'Matcha Agata no Shiro' },
    { jpy: 8640, name: 'Matcha Premium Narino' }
  ];
  
  console.log('\n🧪 Testing other Horiishichimeien products:');
  for (const product of testPrices) {
    const converted = priceUtils.convertToEUR(product.jpy, 'JPY');
    console.log(`💰 ${product.name}: ¥${product.jpy} → €${converted}`);
  }
  
  console.log('\n✅ Exchange rate fix completed!');
}

// Test price cleaning function specifically for Horiishichimeien
function testHoriishichimeienPriceCleaning() {
  console.log('\n🧹 Testing Horiishichimeien Price Cleaning');
  console.log('========================================\n');
  
  const priceUtils = new PriceUtils();
  
  const testCases = [
    'from ¥648 JPY',
    '¥972 JPY',
    'Regular price from ¥648 JPY Sale price from ¥648 JPY',
    'from ¥1,080 JPY',
    '¥8,640 JPY'
  ];
  
  for (const testCase of testCases) {
    const cleaned = priceUtils.cleanPriceBySite(testCase, 'horiishichimeien');
    const priceValue = priceUtils.extractPriceValue(cleaned);
    console.log(`📝 Input: "${testCase}"`);
    console.log(`🧹 Cleaned: "${cleaned}"`);
    console.log(`💰 Price value: ${priceValue}`);
    console.log('');
  }
}

// Run tests
if (require.main === module) {
  testFixedExchangeRate();
  testHoriishichimeienPriceCleaning();
}

module.exports = { testFixedExchangeRate, testHoriishichimeienPriceCleaning };
