const axios = require('axios');

async function testPoppateaProducts() {
    const productUrls = [
        'https://poppatea.com/de-de/products/matcha-tea-ceremonial',
        'https://poppatea.com/de-de/products/matcha-tea-with-chai-ceremonial', 
        'https://poppatea.com/de-de/products/hojicha-tea-powder'
    ];
    
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
    
    for (const url of productUrls) {
        console.log('\n=== Testing URL:', url, '===');
        
        try {
            const response = await axios.get(url, requestConfig);
            const html = response.data;
            
            console.log('Response status:', response.status);
            console.log('HTML length:', html.length);
            
            // Look for variants
            const variantsPattern = /"variants"\s*:\s*(\[.*?\])/s;
            let variantsMatch = html.match(variantsPattern);
            
            if (!variantsMatch) {
                const altPattern1 = /variants:\s*(\[.*?\])/s;
                variantsMatch = html.match(altPattern1);
            }
            
            if (!variantsMatch) {
                const altPattern2 = /window\.ShopifyAnalytics\.meta\.product\.variants\s*=\s*(\[.*?\])/s;
                variantsMatch = html.match(altPattern2);
            }
            
            if (variantsMatch) {
                console.log('Found variants JSON!');
                try {
                    const variants = JSON.parse(variantsMatch[1]);
                    console.log('Variants count:', variants.length);
                    
                    variants.forEach((variant, index) => {
                        console.log(`Variant ${index + 1}:`, {
                            id: variant.id,
                            title: variant.title,
                            name: variant.name,
                            public_title: variant.public_title,
                            available: variant.available,
                            price: variant.price,
                            formatted_price: variant.formatted_price,
                            sku: variant.sku
                        });
                    });
                    
                } catch (parseError) {
                    console.error('Failed to parse variants:', parseError.message);
                }
            } else {
                console.log('No variants pattern found');
            }
            
            // Look for images
            const imageMatches = [...html.matchAll(/<img[^>]+src="((?:https:)?\/\/poppatea\.com\/cdn\/shop\/files\/[^"]*\.jpg[^"]*)"[^>]*>/gi)];
            console.log('Found', imageMatches.length, 'images');
            
            imageMatches.slice(0, 3).forEach((match, index) => {
                console.log(`Image ${index + 1}:`, match[1]);
            });
            
        } catch (error) {
            console.error('Error fetching', url, ':', error.message);
        }
    }
}

testPoppateaProducts();
