const axios = require('axios');

async function testNewPoppateaStructure() {
    const url = 'https://poppatea.com/de-de/collections/all-teas';
    
    const requestConfig = {
        timeout: 30000,
        headers: {
            'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache'
        }
    };
    
    try {
        const response = await axios.get(url, requestConfig);
        const html = response.data;
        
        console.log('=== Testing New Poppatea Structure ===');
        
        // Extract variants
        const variantsPattern = /"variants"\s*:\s*(\[.*?\])/s;
        const variantsMatch = html.match(variantsPattern);
        
        if (variantsMatch) {
            const variants = JSON.parse(variantsMatch[1]);
            console.log('Total variants found:', variants.length);
            
            // Show all variants with their structure
            console.log('\n=== All Variants ===');
            variants.forEach((variant, index) => {
                console.log(`Variant ${index + 1}:`, {
                    id: variant.id,
                    name: variant.name,
                    public_title: variant.public_title,
                    price: variant.price,
                    sku: variant.sku
                });
            });
            
            // Filter for matcha/hojicha products using the 'name' field
            const matchaVariants = variants.filter(variant => {
                if (!variant.price || !variant.name) return false;
                const name = variant.name.toLowerCase();
                return name.includes('matcha') || name.includes('match') || name.includes('hojicha') || name.includes('hoji');
            });
            
            console.log('\n=== Matcha/Hojicha Variants ===');
            console.log('Found', matchaVariants.length, 'matcha/hojicha variants');
            matchaVariants.forEach((variant, index) => {
                console.log(`Matcha ${index + 1}:`, {
                    name: variant.name,
                    price: '€' + (variant.price / 100).toFixed(2),
                    sku: variant.sku
                });
            });
        }
        
        // Also look for availability information in other patterns
        console.log('\n=== Looking for Availability Data ===');
        const availabilityPatterns = [
            /"available"\s*:\s*(true|false)/g,
            /"inventory_quantity"\s*:\s*(\d+)/g,
            /"in_stock"\s*:\s*(true|false)/g
        ];
        
        availabilityPatterns.forEach((pattern, index) => {
            const matches = [...html.matchAll(pattern)];
            console.log(`Pattern ${index + 1} matches:`, matches.length);
            matches.slice(0, 5).forEach((match, i) => {
                console.log(`  Match ${i + 1}:`, match[0]);
            });
        });
        
    } catch (error) {
        console.error('Error:', error.message);
    }
}

testNewPoppateaStructure();
