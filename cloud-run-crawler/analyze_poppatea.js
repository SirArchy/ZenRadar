const axios = require('axios');
const fs = require('fs');

async function analyzePoppateaStructure() {
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
        
        console.log('=== Analyzing Poppatea HTML Structure ===');
        
        // 1. Look for variants pattern
        const variantsPattern = /"variants"\s*:\s*(\[.*?\])/s;
        const variantsMatch = html.match(variantsPattern);
        
        if (variantsMatch) {
            const variants = JSON.parse(variantsMatch[1]);
            console.log('Found', variants.length, 'variants');
            
            // Analyze the structure of variants
            console.log('First variant structure:');
            console.log(JSON.stringify(variants[0], null, 2));
            
            console.log('\nAll variant keys from first variant:');
            console.log(Object.keys(variants[0]));
        }
        
        // 2. Look for products pattern
        const productsPattern = /"products"\s*:\s*(\[.*?\])/s;
        const productsMatch = html.match(productsPattern);
        
        if (productsMatch) {
            const products = JSON.parse(productsMatch[1]);
            console.log('Found', products.length, 'products');
            
            // Analyze the structure of products
            if (products.length > 0) {
                console.log('First product structure:');
                console.log(JSON.stringify(products[0], null, 2));
            }
        }
        
        // 3. Look for other data patterns in JSON
        const jsonPatterns = [
            /"productData"\s*:\s*(\{.*?\})/s,
            /"collectionData"\s*:\s*(\{.*?\})/s,
            /"window\.productVariants"\s*=\s*(\[.*?\])/s,
            /"window\.productData"\s*=\s*(\{.*?\})/s
        ];
        
        jsonPatterns.forEach((pattern, index) => {
            const match = html.match(pattern);
            if (match) {
                console.log(`Found pattern ${index + 1}:`, match[1].substring(0, 200) + '...');
            }
        });
        
        // 4. Look for script tags with JSON data
        const scriptMatches = html.match(/<script[^>]*>(.*?window\..*?=.*?[{\[].*?[}\]].*?)<\/script>/gs);
        if (scriptMatches) {
            console.log('Found', scriptMatches.length, 'script tags with potential JSON data');
            scriptMatches.slice(0, 3).forEach((script, index) => {
                console.log(`Script ${index + 1}:`, script.substring(0, 300) + '...');
            });
        }
        
        // Save HTML for manual inspection
        fs.writeFileSync('poppatea_debug.html', html);
        console.log('Saved HTML to poppatea_debug.html for manual inspection');
        
    } catch (error) {
        console.error('Error:', error.message);
    }
}

analyzePoppateaStructure();
