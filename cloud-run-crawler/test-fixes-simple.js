// Simple test script that doesn't require Firebase initialization
// We'll just test the price and currency functions directly

// Mock the necessary parts
class MockCrawlerService {
  
  cleanPriceBySite(rawPrice, siteKey) {
    if (!rawPrice) return '';
    
    let cleaned = rawPrice.toString().trim();
    
    // Remove common non-price text
    cleaned = cleaned.replace(/Regular price|Sale price|Unit price|per|Sale|Sold out|From|Starting at|Price:/gi, '');
    cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();

    switch (siteKey) {
      case 'sho-cha':
        // Handle German Euro formatting: "5,00€" or "24,00 €"
        const shoChaEuroMatch = cleaned.match(/(\d+(?:,\d{2})?)\s*€/);
        if (shoChaEuroMatch) {
          const price = parseFloat(shoChaEuroMatch[1].replace(',', '.'));
          return `€${price.toFixed(2)}`;
        }
        
        // Try USD format and convert
        const shoChaUsdMatch = cleaned.match(/\$(\d+(?:\.\d{2})?)/);
        if (shoChaUsdMatch) {
          const usdValue = parseFloat(shoChaUsdMatch[1]);
          const euroValue = (usdValue * 0.85).toFixed(2);
          return `€${euroValue}`;
        }
        break;
        
      case 'poppatea':
        // Handle Swedish Krona: "160 kr" and convert to EUR
        const poppatKrMatch = cleaned.match(/(\d+(?:,\d+)?(?:\.\d+)?)\s*kr/);
        if (poppatKrMatch) {
          const amount = parseFloat(poppatKrMatch[1].replace(',', '.'));
          const eurAmount = amount * 0.086; // SEK to EUR conversion
          return `€${eurAmount.toFixed(2)}`;
        }
        
        // Handle EUR prices
        const poppatEurMatch = cleaned.match(/€(\d+(?:,\d+)?(?:\.\d+)?)/);
        if (poppatEurMatch) {
          const amount = parseFloat(poppatEurMatch[1].replace(',', '.'));
          return `€${amount.toFixed(2)}`;
        }
        break;

      case 'horiishichimeien':
        // For Horiishichimeien, handle Japanese Yen prices and convert to Euro
        cleaned = cleaned.replace(/JPY/gi, '');
        
        // Handle comma-separated thousands properly (¥10,800 should be 10800, not 10.8)
        let horiYenMatch = cleaned.match(/¥(\d{1,3}(?:,\d{3})+)/);
        if (horiYenMatch) {
          const jpyValue = parseFloat(horiYenMatch[1].replace(/,/g, ''));
          const euroValue = jpyValue * 0.0065; // Updated JPY to EUR rate
          return `€${euroValue.toFixed(2)}`;
        }
        
        // Handle prices without comma separator
        horiYenMatch = cleaned.match(/¥(\d+)(?!\d)/);
        if (horiYenMatch) {
          const jpyValue = parseFloat(horiYenMatch[1]);
          const euroValue = jpyValue * 0.0065;
          return `€${euroValue.toFixed(2)}`;
        }
        
        // Handle format without currency symbol (assume JPY)
        const horiNumMatch = cleaned.match(/(\d{1,3}(?:,\d{3})+|\d+)/);
        if (horiNumMatch) {
          const jpyValue = parseFloat(horiNumMatch[1].replace(/,/g, ''));
          const euroValue = jpyValue * 0.0065;
          return `€${euroValue.toFixed(2)}`;
        }
        break;
    }

    return cleaned;
  }

  detectCategory(name, site) {
    const lower = name.toLowerCase();

    // Check for accessories first (most specific)
    if (lower.includes('whisk') || lower.includes('chasen') || lower.includes('bowl') || 
        lower.includes('chawan') || lower.includes('scoop') || lower.includes('chashaku') ||
        lower.includes('schale') || lower.includes('becher') || lower.includes('tasse') || 
        lower.includes('teebecher') || lower.includes('teeschale') || lower.includes('schüssel') || 
        lower.includes('teeschüssel')) {
      return 'Accessories';
    }

    // Check for tea sets (also specific)
    if (lower.includes('set') || lower.includes('kit')) {
      return 'Tea Sets';
    }

    // Other tea types (before matcha to catch specific teas)
    if (lower.includes('genmaicha')) return 'Genmaicha';
    if (lower.includes('hojicha')) return 'Hojicha';
    if (lower.includes('black tea') || lower.includes('earl grey')) return 'Black Tea';

    // Matcha - check last since it's most common
    if (lower.includes('matcha')) {
      // Sub-categorize matcha
      if (lower.includes('ceremonial') || lower.includes('ceremony')) return 'Ceremonial Matcha';
      if (lower.includes('premium') || lower.includes('grade a')) return 'Premium Matcha';
      if (lower.includes('cooking') || lower.includes('culinary')) return 'Culinary Matcha';
      return 'Matcha';
    }

    // Default category
    const lowerSite = site.toLowerCase();
    if (lowerSite.includes('matcha') || lowerSite.includes('tea')) {
      return 'Matcha'; // Default for tea sites
    }

    return 'Matcha'; // Default fallback
  }

  parsePriceAndCurrency(priceText) {
    if (!priceText) return { amount: null, currency: 'EUR' };

    const cleaned = priceText.replace(/\s+/g, ' ').trim();
    
    // Currency patterns
    const patterns = [
      { regex: /€(\d+[.,]\d+)/, currency: 'EUR' },           // €12.50
      { regex: /(\d+[.,]\d+)\s*€/, currency: 'EUR' },        // 12.50€ or 5,00€
      { regex: /\$(\d+[.,]\d+)/, currency: 'USD' },          // $12.50
      { regex: /(\d+[.,]\d+)\s*USD/, currency: 'USD' },      // 12.50 USD
      { regex: /CAD\s*(\d+[.,]\d+)/, currency: 'CAD' },      // CAD 15.00
      { regex: /(\d+[.,]\d+)\s*CAD/, currency: 'CAD' },      // 15.00 CAD
      { regex: /¥(\d+(?:,\d{3})*(?:\.\d+)?)/, currency: 'JPY' }, // ¥10,800 or ¥648
      { regex: /(\d+(?:,\d{3})*(?:\.\d+)?)\s*JPY/, currency: 'JPY' }, // 10800 JPY
      { regex: /£(\d+[.,]\d+)/, currency: 'GBP' },           // £12.50
      { regex: /(\d+[.,]\d+)\s*kr/, currency: 'SEK' },       // 160 kr (Poppatea)
      { regex: /(\d+[.,]\d+)\s*DKK/, currency: 'DKK' },      // 12.50 DKK
      { regex: /(\d+[.,]\d+)\s*NOK/, currency: 'NOK' },      // 12.50 NOK
    ];

    for (const pattern of patterns) {
      const match = cleaned.match(pattern.regex);
      if (match) {
        const amountStr = match[1].replace(',', '.');
        const amount = parseFloat(amountStr);
        
        if (!isNaN(amount) && amount > 0) {
          return { amount, currency: pattern.currency };
        }
      }
    }

    // Fallback: try to extract any number and assume EUR
    const numberMatch = cleaned.match(/(\d+[.,]\d+)/);
    if (numberMatch) {
      const amountStr = numberMatch[1].replace(',', '.');
      const amount = parseFloat(amountStr);
      if (!isNaN(amount) && amount > 0) {
        return { amount, currency: 'EUR' };
      }
    }

    return { amount: null, currency: 'EUR' };
  }

  convertToEURSync(amount, fromCurrency) {
    if (!amount || fromCurrency === 'EUR') {
      return amount;
    }

    const exchangeRates = {
      'USD': 0.85,
      'CAD': 0.63,
      'JPY': 0.0065, // Updated rate
      'GBP': 1.17,
      'SEK': 0.086,
      'DKK': 0.134,
      'NOK': 0.085,
    };

    const rate = exchangeRates[fromCurrency];
    return rate ? amount * rate : amount;
  }
}

async function testAllFixes() {
  const crawler = new MockCrawlerService();
  
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

// Run tests
testAllFixes().catch(console.error);
