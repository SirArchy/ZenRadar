const PoppateaSpecializedCrawler = require('./src/crawlers/poppatea-crawler');

// Test the ID generation with the specific products mentioned
function testIdGeneration() {
    const crawler = new PoppateaSpecializedCrawler();
    
    console.log('🧪 Testing Poppatea ID generation...\n');
    
    // Test cases for the mentioned products - reverse engineered from expected IDs
    const testCases = [
        {
            // This should generate: poppatea_matchateaceremonial_matchateezeremoniell
            url: 'https://poppatea.com/de-de/products/matcha-tea-ceremonial',
            name: 'Matcha Tee - Zeremoniell - 50g Dose (50 Portionen)',
            expected: 'poppatea_matchateaceremonial_matchateezeremoniell'
        },
        {
            // This should generate: poppatea_matchateawithchaiceremonial_matchateemitchaizere
            url: 'https://poppatea.com/de-de/products/matcha-tea-with-chai-ceremonial', 
            name: 'Matcha Tee mit Chai - Zeremoniell - 50g Dose (50 Portionen)',
            expected: 'poppatea_matchateawithchaiceremonial_matchateemitchaizere'
        },
        {
            // This should generate: poppatea_hojichateapowder_hojichateepulver
            url: 'https://poppatea.com/de-de/products/hojicha-tea-powder',
            name: 'Hojichatee Pulver', 
            expected: 'poppatea_hojichateapowder_hojichateepulver'
        }
    ];
    
    // Let's also test what URLs would generate the expected IDs
    console.log('🔍 Reverse engineering the correct URLs and names...\n');
    
    // For poppatea_matchateaceremonial_matchateezeremoniell
    const reverseTests = [
        {
            url: 'https://poppatea.com/de-de/products/matcha-tea-ceremonial', 
            name: 'Matcha Tee Zeremoniell',
            target: 'poppatea_matchateaceremonial_matchateezeremoniell'
        },
        {
            url: 'https://poppatea.com/de-de/products/matcha-tea-with-chai-ceremonial',
            name: 'Matcha Tee mit Chai Zeremoniell',  
            target: 'poppatea_matchateawithchaiceremonial_matchateemitchaizere'
        }
    ];
    
    testCases.forEach((testCase, index) => {
        const generatedId = crawler.generateProductId(testCase.url, testCase.name);
        console.log(`${index + 1}. Current test case:`);
        console.log(`   URL: ${testCase.url}`);
        console.log(`   Name: ${testCase.name}`);
        console.log(`   Generated: ${generatedId}`);
        console.log(`   Expected:  ${testCase.expected}`);
        console.log(`   Match: ${generatedId === testCase.expected ? '✅' : '❌'}`);
        console.log('');
    });
    
    console.log('🧪 Testing reverse engineered cases...\n');
    
    reverseTests.forEach((testCase, index) => {
        const generatedId = crawler.generateProductId(testCase.url, testCase.name);
        console.log(`${index + 1}. Reverse test:`);
        console.log(`   URL: ${testCase.url}`);
        console.log(`   Name: ${testCase.name}`);
        console.log(`   Generated: ${generatedId}`);
        console.log(`   Target:    ${testCase.target}`);
        console.log(`   Match: ${generatedId === testCase.target ? '✅' : '❌'}`);
        console.log('');
    });
}

testIdGeneration();
