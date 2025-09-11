const axios = require('axios');

async function testImageMatchingLogic() {
    console.log('=== Testing Image Matching Logic ===');
    
    const testUrls = [
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
    
    for (const productUrl of testUrls) {
        console.log(`\n=== Testing ${productUrl} ===`);
        
        try {
            const response = await axios.get(productUrl, requestConfig);
            const html = response.data;
            
            // Extract product image using the same logic as the crawler
            let productImage = null;
            try {
                // Extract all matching images and find the best one for this product
                const allImageMatches = [...html.matchAll(/<img[^>]+src="((?:https:)?\/\/poppatea\.com\/cdn\/shop\/files\/[^"]*\.jpg[^"]*)"[^>]*>/gi)];
                
                console.log(`Found ${allImageMatches.length} total image matches`);
                
                for (const match of allImageMatches) {
                    let imgUrl = match[1];
                    // Normalize protocol-relative URLs
                    if (imgUrl.startsWith('//')) {
                        imgUrl = 'https:' + imgUrl;
                    }
                    const imgName = imgUrl.toLowerCase();
                    
                    console.log(`  Checking image: ${imgName}`);
                    
                    // Match specific product images based on URL content
                    if (productUrl.includes('matcha-tea-ceremonial') && !productUrl.includes('chai')) {
                        if (imgName.includes('matcha_tea') && !imgName.includes('chai')) {
                            console.log(`  ✓ MATCHED for matcha-tea-ceremonial: ${imgUrl}`);
                            productImage = imgUrl;
                            break;
                        }
                    } else if (productUrl.includes('matcha-tea-with-chai')) {
                        if (imgName.includes('matcha_tea_with_chai') || (imgName.includes('chai') && imgName.includes('matcha'))) {
                            console.log(`  ✓ MATCHED for matcha-tea-with-chai: ${imgUrl}`);
                            productImage = imgUrl;
                            break;
                        }
                    } else if (productUrl.includes('hojicha-tea-powder')) {
                        if (imgName.includes('hojicha')) {
                            console.log(`  ✓ MATCHED for hojicha-tea-powder: ${imgUrl}`);
                            productImage = imgUrl;
                            break;
                        }
                    }
                }
                
                // Clean up URL parameters for consistency  
                if (productImage && productImage.includes('?')) {
                    productImage = productImage.split('?')[0];
                }
                
                if (productImage) {
                    console.log(`Final selected image: ${productImage}`);
                } else {
                    console.log('No matching image found');
                }
                
            } catch (imageError) {
                console.error('Image extraction error:', imageError.message);
            }
            
        } catch (error) {
            console.error('Request error:', error.message);
        }
    }
}

testImageMatchingLogic();
