const axios = require('axios');

async function testRegexPattern() {
    try {
        const response = await axios.get('https://poppatea.com/de-de/products/matcha-tea-ceremonial');
        const html = response.data;
        
        console.log('=== Testing different regex patterns ===');
        
        // Pattern 1: Our current pattern
        const pattern1 = /<img[^>]+src="((?:https:)?\/\/poppatea\.com\/cdn\/shop\/files\/[^"]*\.jpg[^"]*)"[^>]*>/gi;
        const matches1 = [...html.matchAll(pattern1)];
        console.log(`Pattern 1 (current): Found ${matches1.length} matches`);
        matches1.slice(0, 3).forEach((match, i) => {
            console.log(`  Match ${i+1}: ${match[1]}`);
        });
        
        // Pattern 2: Simpler pattern
        const pattern2 = /src="(\/\/poppatea\.com\/cdn\/shop\/files\/[^"]*\.jpg[^"]*)"/gi;
        const matches2 = [...html.matchAll(pattern2)];
        console.log(`\nPattern 2 (simpler): Found ${matches2.length} matches`);
        matches2.slice(0, 3).forEach((match, i) => {
            console.log(`  Match ${i+1}: ${match[1]}`);
        });
        
        // Pattern 3: Even more relaxed
        const pattern3 = /\/\/poppatea\.com\/cdn\/shop\/files\/[^"\s]*\.jpg[^"\s]*/gi;
        const matches3 = html.match(pattern3);
        console.log(`\nPattern 3 (most relaxed): Found ${matches3 ? matches3.length : 0} matches`);
        if (matches3) {
            matches3.slice(0, 3).forEach((match, i) => {
                console.log(`  Match ${i+1}: ${match}`);
            });
        }
        
        // Pattern 4: Look for any image with matcha in name
        const pattern4 = /\/\/poppatea\.com\/cdn\/shop\/files\/[^"\s]*matcha[^"\s]*\.jpg[^"\s]*/gi;
        const matches4 = html.match(pattern4);
        console.log(`\nPattern 4 (matcha specific): Found ${matches4 ? matches4.length : 0} matches`);
        if (matches4) {
            matches4.forEach((match, i) => {
                console.log(`  Match ${i+1}: ${match}`);
            });
        }
        
    } catch (error) {
        console.error('Error testing regex patterns:', error.message);
    }
}

testRegexPattern();
