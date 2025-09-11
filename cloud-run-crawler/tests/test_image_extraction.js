const axios = require('axios');
const cheerio = require('cheerio');

async function testImageExtraction() {
    try {
        const response = await axios.get('https://poppatea.com/de-de/products/matcha-tea-ceremonial');
        const $ = cheerio.load(response.data);
        
        console.log('=== Looking for image patterns ===');
        
        // Check for img tags
        const imgTags = $('img').length;
        console.log(`Found ${imgTags} img tags total`);
        
        // Check product images specifically
        const productImages = $('img[src*="cdn.shopify.com"]').length;
        console.log(`Found ${productImages} Shopify CDN images`);
        
        // Sample a few img tags to see their structure
        console.log('\n=== Sample img tags ===');
        $('img').slice(0, 5).each((i, el) => {
            const src = $(el).attr('src');
            const alt = $(el).attr('alt');
            const classes = $(el).attr('class');
            console.log(`Img ${i+1}: src="${src}", alt="${alt}", class="${classes}"`);
        });
        
        // Look for any images with product-related classes or IDs
        console.log('\n=== Product-specific images ===');
        $('img[class*="product"], img[id*="product"], img[class*="image"], img[data-*]').each((i, el) => {
            const src = $(el).attr('src');
            const alt = $(el).attr('alt');
            const classes = $(el).attr('class');
            const dataAttrs = Object.keys(el.attribs).filter(attr => attr.startsWith('data-'));
            console.log(`Product img ${i+1}: src="${src}", alt="${alt}", class="${classes}", data-attrs=[${dataAttrs.join(', ')}]`);
        });
        
        // Check for any script tags containing image URLs
        console.log('\n=== Images in script tags ===');
        let imageUrlsInScripts = [];
        $('script').each((i, el) => {
            const content = $(el).html();
            if (content) {
                const matches = content.match(/https:\/\/[^"\s]*\.(?:jpg|jpeg|png|webp|gif)[^"\s]*/gi);
                if (matches) {
                    imageUrlsInScripts.push(...matches);
                }
            }
        });
        console.log(`Found ${imageUrlsInScripts.length} image URLs in scripts`);
        imageUrlsInScripts.slice(0, 5).forEach((url, i) => {
            console.log(`Script img ${i+1}: ${url}`);
        });
        
    } catch (error) {
        console.error('Error testing image extraction:', error.message);
    }
}

testImageExtraction();
