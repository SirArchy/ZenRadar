const axios = require('axios');

async function testAlternativeUrls() {
  console.log('🔍 Testing Alternative URLs for Missing Sites\n');
  
  const testSites = [
    {
      name: 'Matcha-Kāru',
      urls: [
        'https://matcha-karu.com',
        'https://matcha-karu.com/collections/all',
        'https://www.matcha-karu.com',
        'https://matcha-karu.de'
      ]
    },
    {
      name: 'Sho-Cha',
      urls: [
        'https://sho-cha.jp',
        'https://www.sho-cha.jp',
        'https://sho-cha.com',
        'https://www.sho-cha.com'
      ]
    },
    {
      name: 'Poppatea',
      urls: [
        'https://poppatea.com',
        'https://poppatea.com/collections/all',
        'https://www.poppatea.com',
        'https://poppatea.de'
      ]
    }
  ];
  
  for (const site of testSites) {
    console.log(`\n🧪 Testing ${site.name}:`);
    
    for (const url of site.urls) {
      try {
        const response = await axios.get(url, {
          timeout: 5000,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          }
        });
        console.log(`✅ ${url} - Status: ${response.status}`);
        
        // Check if it looks like an e-commerce site
        const content = response.data.toLowerCase();
        if (content.includes('matcha') && (content.includes('add to cart') || content.includes('price') || content.includes('shop'))) {
          console.log(`   🛍️  Looks like a matcha shop!`);
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
}

testAlternativeUrls().catch(console.error);
