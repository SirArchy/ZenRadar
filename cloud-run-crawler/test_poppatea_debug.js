const axios = require('axios');
const cheerio = require('cheerio');

async function testPoppateaAccess() {
    const url = 'https://poppatea.com/de-de/collections/all-teas';
    
    console.log('Testing Poppatea URL:', url);
    
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
        console.log('Fetching with headers:', JSON.stringify(requestConfig.headers, null, 2));
        
        const response = await axios.get(url, requestConfig);
        
        console.log('Response status:', response.status);
        console.log('Response headers:', JSON.stringify(response.headers, null, 2));
        console.log('Response data length:', response.data.length);
        
        // Check if response contains products
        const html = response.data;
        console.log('HTML contains "variants":', html.includes('variants'));
        console.log('HTML contains "product":', html.includes('product'));
        console.log('HTML contains "matcha":', html.includes('matcha'));
        
        // Try to find variants pattern
        const variantsPattern = /"variants"\s*:\s*(\[.*?\])/s;
        const variantsMatch = html.match(variantsPattern);
        
        if (variantsMatch) {
            console.log('Found variants pattern!');
            try {
                const variants = JSON.parse(variantsMatch[1]);
                console.log('Successfully parsed', variants.length, 'variants');
                
                // Show first few variants
                variants.slice(0, 3).forEach((variant, index) => {
                    console.log(`Variant ${index + 1}:`, {
                        id: variant.id,
                        title: variant.title,
                        available: variant.available,
                        price: variant.price
                    });
                });
                
                // Filter for matcha/hojicha
                const matchaVariants = variants.filter(variant => {
                    if (!variant.available || !variant.price || !variant.title) return false;
                    const title = variant.title.toLowerCase();
                    return title.includes('matcha') || title.includes('match') || title.includes('hojicha') || title.includes('hoji');
                });
                
                console.log('Found', matchaVariants.length, 'matcha/hojicha variants');
                matchaVariants.slice(0, 5).forEach((variant, index) => {
                    console.log(`Matcha variant ${index + 1}:`, variant.title);
                });
                
            } catch (parseError) {
                console.error('Failed to parse variants JSON:', parseError.message);
            }
        } else {
            console.log('No variants pattern found in HTML');
            
            // Let's look for other patterns
            console.log('Looking for alternative patterns...');
            console.log('HTML contains "product-card":', html.includes('product-card'));
            console.log('HTML contains "collection":', html.includes('collection'));
            
            // Show first 1000 characters to see what we're getting
            console.log('First 1000 chars of HTML:');
            console.log(html.substring(0, 1000));
        }
        
    } catch (error) {
        console.error('Error fetching Poppatea:', error.message);
        if (error.response) {
            console.error('Response status:', error.response.status);
            console.error('Response data:', error.response.data);
        }
    }
}

testPoppateaAccess();
