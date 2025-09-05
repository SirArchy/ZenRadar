const axios = require('axios');

async function testYoshienCrawler() {
  try {
    console.log('Testing deployed Yoshien crawler...');
    
    const response = await axios.post(
      'https://zenradar-crawler-989787576521.europe-west3.run.app/crawl',
      {
        sites: ['yoshien']
      },
      {
        headers: {
          'Content-Type': 'application/json'
        },
        timeout: 30000
      }
    );
    
    console.log('\nResponse Status:', response.status);
    console.log('Response Data:', JSON.stringify(response.data, null, 2));
    
    if (response.data.success) {
      const yoshienResults = response.data.results.find(r => r.site === 'yoshien');
      if (yoshienResults) {
        console.log(`\n✅ Yoshien Crawler Working!`);
        console.log(`Found ${yoshienResults.products.length} products`);
        if (yoshienResults.products.length > 0) {
          console.log('\nSample products:');
          yoshienResults.products.slice(0, 3).forEach((product, index) => {
            console.log(`${index + 1}. ${product.name} - ${product.price}`);
          });
        }
      } else {
        console.log('❌ No Yoshien results in response');
      }
    } else {
      console.log('❌ Crawler request failed:', response.data.error);
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    if (error.response) {
      console.error('Response status:', error.response.status);
      console.error('Response data:', error.response.data);
    }
  }
}

testYoshienCrawler();
