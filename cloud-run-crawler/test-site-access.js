const axios = require('axios');

// Quick test to check site availability and structure
async function testSiteAccess() {
  const sites = [
    { name: 'Sho-Cha', url: 'https://sho-cha.de' },
    { name: 'Poppatea', url: 'https://poppatea.se' },
    { name: 'Marukyu-Koyamaen', url: 'https://www.marukyu-koyamaen.co.jp/english' },
    { name: 'Ippodo Tea', url: 'https://global.ippodo-tea.co.jp' },
    { name: 'Sazentea', url: 'https://sazentea.de' }
  ];

  for (const site of sites) {
    console.log(`\n🌐 Testing ${site.name}: ${site.url}`);
    
    try {
      const response = await axios.get(site.url, {
        timeout: 10000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
      });
      
      console.log(`✅ Response: ${response.status} ${response.statusText}`);
      console.log(`📄 Content length: ${response.data.length} characters`);
      
      // Check if it's a typical e-commerce site
      if (response.data.includes('product') || response.data.includes('matcha') || 
          response.data.includes('tea') || response.data.includes('shop')) {
        console.log(`🛍️  Appears to be e-commerce site`);
      }
      
    } catch (error) {
      console.log(`❌ Error: ${error.message}`);
      if (error.code === 'ENOTFOUND') {
        console.log(`🚫 DNS resolution failed - domain may not exist`);
      } else if (error.response) {
        console.log(`📄 HTTP Error: ${error.response.status}`);
      }
    }
  }
}

testSiteAccess().catch(console.error);
