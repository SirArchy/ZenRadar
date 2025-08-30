// Quick test to verify Horiishichimeien price conversion fix
function testHoriPriceConversion() {
    console.log('🧪 Testing Horiishichimeien Price Conversion\n');
    
    const testPrices = [
        '¥10,800 JPY',
        'Regular price ¥10,800 JPY Sale price ¥10,800 JPY',
        '¥8,640 JPY',
        '¥1,500',
        '¥500'
    ];
    
    for (const rawPrice of testPrices) {
        let cleaned = rawPrice.trim();
        cleaned = cleaned.replace(/\n/g, ' ').replace(/\s+/g, ' ');
        cleaned = cleaned.replace(/Regular price|Sale price|Unit price|per|Sale|Sold out|JPY/gi, '');
        
        console.log(`Input: "${rawPrice}"`);
        console.log(`Cleaned: "${cleaned}"`);
        
        // Extract only the first valid Yen price to avoid duplicates
        // Fix: Handle comma-separated thousands properly (¥10,800 should be 10800, not 10)
        let horiYenMatch = cleaned.match(/¥(\d{1,3}(?:,\d{3})+)/); // With comma separator for thousands
        if (horiYenMatch) {
            const jpyValue = parseFloat(horiYenMatch[1].replace(/,/g, '')); // Remove commas: "10,800" -> 10800
            const euroValue = (jpyValue * 0.0067).toFixed(2);
            console.log(`✅ Matched with commas: ${horiYenMatch[1]} -> JPY ${jpyValue} -> €${euroValue}`);
        } else {
            // Handle prices without comma separator (for amounts under 1000)
            horiYenMatch = cleaned.match(/¥(\d+)(?!\d)/); // Ensure we don't partial match longer numbers
            if (horiYenMatch) {
                const jpyValue = parseFloat(horiYenMatch[1]);
                const euroValue = (jpyValue * 0.0067).toFixed(2);
                console.log(`✅ Matched without commas: ${horiYenMatch[1]} -> JPY ${jpyValue} -> €${euroValue}`);
            } else {
                console.log(`❌ No match found`);
            }
        }
        console.log('---');
    }
}

testHoriPriceConversion();
