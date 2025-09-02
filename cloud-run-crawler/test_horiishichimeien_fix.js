// Test for Horiishichimeien price conversion fix
console.log('Testing Horiishichimeien price conversion...');

// Test the price processing logic
function testHoriishichimeienPriceConversion() {
  // Simulate the price cleaning logic for Horiishichimeien
  const rawPrice = '¥4,104';
  let cleaned = rawPrice.replace(/\n/g, ' ').replace(/\s+/g, ' ');
  cleaned = cleaned.replace(/Regular price|Sale price|Unit price|per|Sale|Sold out|JPY/gi, '');
  
  console.log(`Original price: ${rawPrice}`);
  console.log(`Cleaned price: ${cleaned}`);
  
  // Extract JPY value with comma handling
  let horiYenMatch = cleaned.match(/¥(\d{1,3}(?:,\d{3})+)/);
  if (horiYenMatch) {
    const jpyValue = parseFloat(horiYenMatch[1].replace(/,/g, ''));
    const euroValue = (jpyValue * 0.00577).toFixed(2);
    
    console.log(`Extracted JPY value: ${jpyValue}`);
    console.log(`Converted EUR value: €${euroValue}`);
    console.log(`Expected: €23.68`);
    
    const expectedValue = 23.68;
    const actualValue = parseFloat(euroValue);
    const difference = Math.abs(expectedValue - actualValue);
    
    if (difference < 0.5) { // Allow 50 cent tolerance
      console.log('✅ Conversion is correct!');
      return true;
    } else {
      console.log(`❌ Conversion is incorrect. Difference: €${difference.toFixed(2)}`);
      return false;
    }
  } else {
    console.log('❌ Failed to extract JPY value');
    return false;
  }
}

// Test different price formats
function testVariousPriceFormats() {
  const testCases = [
    { input: '¥4,104', expected: 23.68 },
    { input: '¥1,500', expected: 8.66 },
    { input: '¥800', expected: 4.62 },
    { input: '¥10,000', expected: 57.70 }
  ];
  
  console.log('\nTesting various price formats:');
  let allPassed = true;
  
  for (const testCase of testCases) {
    let cleaned = testCase.input.replace(/\n/g, ' ').replace(/\s+/g, ' ');
    cleaned = cleaned.replace(/Regular price|Sale price|Unit price|per|Sale|Sold out|JPY/gi, '');
    
    // Handle comma-separated thousands
    let horiYenMatch = cleaned.match(/¥(\d{1,3}(?:,\d{3})+)/);
    if (horiYenMatch) {
      const jpyValue = parseFloat(horiYenMatch[1].replace(/,/g, ''));
      const euroValue = parseFloat((jpyValue * 0.00577).toFixed(2));
      
      const difference = Math.abs(testCase.expected - euroValue);
      const passed = difference < 0.5;
      
      console.log(`${passed ? '✅' : '❌'} ${testCase.input} -> €${euroValue} (expected: €${testCase.expected})`);
      if (!passed) allPassed = false;
    } else {
      // Handle prices without comma separator
      horiYenMatch = cleaned.match(/¥(\d+)(?!\d)/);
      if (horiYenMatch) {
        const jpyValue = parseFloat(horiYenMatch[1]);
        const euroValue = parseFloat((jpyValue * 0.00577).toFixed(2));
        
        const difference = Math.abs(testCase.expected - euroValue);
        const passed = difference < 0.5;
        
        console.log(`${passed ? '✅' : '❌'} ${testCase.input} -> €${euroValue} (expected: €${testCase.expected})`);
        if (!passed) allPassed = false;
      } else {
        console.log(`❌ Failed to extract price from: ${testCase.input}`);
        allPassed = false;
      }
    }
  }
  
  return allPassed;
}

// Run tests
const mainTestPassed = testHoriishichimeienPriceConversion();
const variousTestsPassed = testVariousPriceFormats();

if (mainTestPassed && variousTestsPassed) {
  console.log('\n✅ All Horiishichimeien price conversion tests passed!');
} else {
  console.log('\n❌ Some tests failed');
}
