const axios = require('axios');
const cheerio = require('cheerio');

async function testEmeriSite() {
    try {
        console.log('Testing Emeri main site...');
        const response = await axios.get('https://emeri.co.uk', {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
        });
        
        console.log('Main site status:', response.status);
        
        const $ = cheerio.load(response.data);
        
        // Look for collection links
        const collectionLinks = [];
        $('a[href*="collections"]').each((i, el) => {
            const href = $(el).attr('href');
            if (href) {
                collectionLinks.push(href);
            }
        });
        
        console.log('Collection links found:', [...new Set(collectionLinks)]);
        
        // Look for product links
        const productLinks = [];
        $('a[href*="products"]').each((i, el) => {
            const href = $(el).attr('href');
            if (href) {
                productLinks.push(href);
            }
        });
        
        console.log('Product links found:', productLinks.slice(0, 5));
        
        // Check for any matcha-related content
        const matchaText = $('body').text().toLowerCase();
        console.log('Contains "matcha":', matchaText.includes('matcha'));
        
    } catch (error) {
        console.error('Error testing Emeri site:', error.message);
    }
}

testEmeriSite();
