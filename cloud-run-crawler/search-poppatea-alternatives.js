const axios = require('axios');

async function searchForPoppateaAlternatives() {
  console.log('🔍 Searching for Poppatea Alternative Domains\n');
  
  // Try various alternative domains and subdomains
  const alternativeUrls = [
    'https://poppatea.com',
    'https://www.poppatea.com',
    'https://poppatea.eu',
    'https://poppatea.net',
    'https://shop.poppatea.se',
    'https://store.poppatea.se',
    'https://poppatea.shop',
    'https://poppatea.store',
    // Swedish domain alternatives
    'https://poppatea.sverige.se',
    'https://poppateas.se',
    'https://poppatea-se.com'
  ];

  for (const url of alternativeUrls) {
    console.log(`🌐 Testing: ${url}`);
    
    try {
      const response = await axios.get(url, {
        timeout: 10000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
      });
      
      console.log(`✅ FOUND! Status: ${response.status}`);
      console.log(`📄 Content length: ${response.data.length}`);
      
      if (response.data.toLowerCase().includes('matcha') || 
          response.data.toLowerCase().includes('tea') ||
          response.data.toLowerCase().includes('poppatea')) {
        console.log(`🍵 Tea-related content detected!`);
        console.log(`🎯 POTENTIAL WORKING DOMAIN: ${url}`);
        return url;
      }
      
    } catch (error) {
      console.log(`❌ ${error.code || error.message}`);
    }
  }
  
  console.log('\n❌ No working Poppatea domains found');
  console.log('💡 Recommendations:');
  console.log('   1. Site may be temporarily down');
  console.log('   2. Domain may have changed or expired');
  console.log('   3. Consider removing from active monitoring until resolved');
  
  return null;
}

if (require.main === module) {
  searchForPoppateaAlternatives().catch(console.error);
}
