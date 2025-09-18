/**
 * Final test to confirm Emeri image extraction is working
 * This simulates the actual crawler behavior
 */

const axios = require('axios');
const cheerio = require('cheerio');

// Simulate the crawler's extractImageUrl method
function extractImageUrl(productElement, baseUrl, logger = console) {
    const selectors = [
        'img.product-media__image',  // Images with product-media__image class directly
        '.product-media__image img', // Original selector as fallback
        '.product-card__image img',
        '.product-image img',
        '.card__media img',
        'img[src*="cdn/shop/files/"]', // Emeri uses cdn/shop/files instead of products
        'img[alt*="Matcha"], img[alt*="Bowl"], img[alt*="Whisk"]' // Alt text based matching
    ];
    
    for (const selector of selectors) {
        const img = productElement.find(selector).first();
        if (img.length) {
            let imageUrl = img.attr('src') || img.attr('data-src') || img.attr('data-original');
            
            // Handle lazy loading attributes
            if (!imageUrl) {
                imageUrl = img.attr('data-lazy') || 
                          img.attr('data-srcset') || 
                          img.attr('srcset');
                
                if (imageUrl && imageUrl.includes(',')) {
                    // Extract highest resolution from srcset
                    const srcsetParts = imageUrl.split(',');
                    const highestRes = srcsetParts[srcsetParts.length - 1].trim();
                    imageUrl = highestRes.split(' ')[0];
                }
            }

            if (imageUrl) {
                // Handle protocol-relative URLs (common in Emeri)
                if (imageUrl.startsWith('//')) {
                    imageUrl = 'https:' + imageUrl;
                } else if (imageUrl.startsWith('/')) {
                    imageUrl = baseUrl + imageUrl;
                }

                // Validate URL
                if (imageUrl.includes('cdn.shop') || imageUrl.includes('enjoyemeri')) {
                    // Remove width parameter for higher quality
                    const cleanUrl = imageUrl.split('?')[0] + '?width=800'; // Set consistent width
                    
                    logger.info('Found Emeri product image', {
                        selector,
                        imageUrl: cleanUrl,
                        alt: img.attr('alt')
                    });
                    
                    return cleanUrl;
                }
            }
        }
    }

    logger.warn('No valid image URL found for Emeri product');
    return null;
}

async function testCompleteEmeriFlow() {
    console.log('🧪 Testing Complete Emeri Crawler Flow...\n');
    
    try {
        const categoryUrl = 'https://www.enjoyemeri.com/collections/shop-all';
        const baseUrl = 'https://enjoyemeri.com';
        
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

        console.log('📄 Fetching category page...');
        const response = await axios.get(categoryUrl, requestConfig);
        const $ = cheerio.load(response.data);
        
        console.log(`✅ Status: ${response.status}`);
        console.log(`📋 Page title: ${$('title').text()}\n`);
        
        // Find product cards
        const productCards = $('.product-card');
        console.log(`🛍️ Found ${productCards.length} product cards\n`);
        
        // Test first few products
        const maxProducts = Math.min(3, productCards.length);
        
        for (let i = 0; i < maxProducts; i++) {
            const productElement = $(productCards[i]);
            console.log(`--- Testing Product ${i + 1} ---`);
            
            // Extract product name
            const productName = productElement.find('h3, .product-title, .product-card__title').first().text().trim();
            console.log(`📦 Product: ${productName}`);
            
            // Extract product link
            const productLink = productElement.find('a').first().attr('href');
            const fullLink = productLink ? (productLink.startsWith('http') ? productLink : baseUrl + productLink) : null;
            console.log(`🔗 Link: ${fullLink}`);
            
            // Test image extraction
            const imageUrl = extractImageUrl(productElement, baseUrl);
            
            if (imageUrl) {
                console.log(`✅ Image found: ${imageUrl}`);
                
                // Test image accessibility
                try {
                    const imageResponse = await axios.head(imageUrl, { timeout: 5000 });
                    console.log(`🖼️ Image accessible (${imageResponse.status}, ${imageResponse.headers['content-type']})`);
                } catch (imageError) {
                    console.log(`❌ Image error: ${imageError.message}`);
                }
            } else {
                console.log(`❌ No image found`);
            }
            
            console.log(''); // Empty line for separation
        }
        
        console.log('🎉 Complete flow test completed successfully!');
        
    } catch (error) {
        console.error('❌ Complete flow test failed:', error.message);
    }
}

testCompleteEmeriFlow();
