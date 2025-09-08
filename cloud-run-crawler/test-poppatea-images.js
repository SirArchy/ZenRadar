// Test script to find Poppatea product images in HTML
const axios = require('axios');

async function findImages() {
    const productUrls = [
        'https://poppatea.com/de-de/products/matcha-tea-ceremonial',
        'https://poppatea.com/de-de/products/matcha-tea-with-chai-ceremonial', 
        'https://poppatea.com/de-de/products/hojicha-tea-powder'
    ];
    
    for (const productUrl of productUrls) {
        console.log(`\n🔍 Analyzing images for: ${productUrl}`);
        
        try {
            const response = await axios.get(productUrl, {
                timeout: 30000,
                headers: {
                    'User-Agent': 'ZenRadar Bot 1.0 (+https://zenradar.app)',
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                    'Accept-Language': 'en-US,en;q=0.5',
                }
            });
            
            const html = response.data;
            
            // Look for different image patterns in Shopify stores
            console.log('\n📸 Searching for image patterns...');
            
            // Updated patterns to match Poppatea's actual structure
            const imagePatterns = [
                // Shopify featured image pattern
                { name: 'window.product featured_image', pattern: /window\.product\s*=\s*\{[^}]*"featured_image"\s*:\s*"([^"]+)"/ },
                // Product object with featured_image
                { name: 'featured_image', pattern: /"featured_image"\s*:\s*"([^"]+)"/ },
                // JSON-LD structured data
                { name: 'JSON-LD image', pattern: /"image"\s*:\s*"([^"]+)"/ },
                // IMG tags with Shopify CDN
                { name: 'Shopify CDN img tags', pattern: /<img[^>]+src="(https:\/\/cdn\.shopify\.com\/[^"]*\.(?:jpg|jpeg|png|webp)[^"]*)"[^>]*>/gi },
                // General CDN images
                { name: 'General img tags', pattern: /<img[^>]+src="([^"]*\.(?:jpg|jpeg|png|webp)[^"]*)"[^>]*>/gi }
            ];
            
            let foundImage = false;
            
            for (const { name, pattern } of imagePatterns) {
                const matches = pattern.global ? [...html.matchAll(pattern)] : [html.match(pattern)];
                
                if (matches && matches[0] && matches[0][1]) {
                    console.log(`✅ Found ${name}:`);
                    
                    const urls = matches.map(match => match[1]).filter(Boolean);
                    const uniqueUrls = [...new Set(urls)];
                    
                    uniqueUrls.slice(0, 5).forEach((url, i) => {
                        let processedUrl = url;
                        if (url.startsWith('//')) {
                            processedUrl = 'https:' + url;
                        } else if (url.startsWith('/')) {
                            processedUrl = 'https://poppatea.com' + url;
                        }
                        console.log(`   ${i + 1}. ${processedUrl}`);
                    });
                    
                    if (uniqueUrls.length > 5) {
                        console.log(`   ... and ${uniqueUrls.length - 5} more`);
                    }
                    
                    foundImage = true;
                }
            }
            
            if (!foundImage) {
                console.log('❌ No images found with current patterns');
                
                // Try to find any image-related content for debugging
                console.log('\n🔍 Searching for any image-related patterns...');
                
                const debugPatterns = [
                    'featured_image',
                    'product_image',
                    'cdn.shopify.com',
                    'shopify-images',
                    '"image"',
                    '.jpg',
                    '.png',
                    '.webp'
                ];
                
                for (const searchTerm of debugPatterns) {
                    const count = (html.match(new RegExp(searchTerm, 'gi')) || []).length;
                    if (count > 0) {
                        console.log(`   "${searchTerm}": ${count} occurrences`);
                    }
                }
            }
            
        } catch (error) {
            console.error('❌ Error fetching product:', error.message);
        }
    }
}

findImages().catch(console.error);
