const axios = require('axios');

async function testShoChaUrls() {
  console.log('🔍 Testing Sho-Cha URL variations\n');
  
  const urls = [
    'https://sho-cha.com',
    'https://sho-cha.com/collections/all',
    'https://sho-cha.com/products',
    'https://sho-cha.com/shop',
    'https://sho-cha.com/collections/tea',
    'https://sho-cha.com/collections/matcha-tea'
  ];
  
  for (const url of urls) {
    try {
      const response = await axios.get(url, {
        timeout: 5000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
      });
      
      console.log(`✅ ${url} - Status: ${response.status}`);
      
      const content = response.data.toLowerCase();
      if (content.includes('matcha') && content.includes('price')) {
        console.log(`   🛍️  Contains products with prices!`);
      }
      
      // Check for navigation or product links
      const cheerio = require('cheerio');
      const $ = cheerio.load(response.data);
      const matchaLinks = $('a[href*="matcha"], a[href*="tea"]').length;
      if (matchaLinks > 0) {
        console.log(`   🔗 Found ${matchaLinks} potential product/category links`);
      }
      
    } catch (error) {
      if (error.response) {
        console.log(`❌ ${url} - Status: ${error.response.status}`);
      } else {
        console.log(`❌ ${url} - ${error.message}`);
      }
    }
  }
}

testShoChaUrls().catch(console.error);
