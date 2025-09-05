const axios = require('axios');

async function testPoppateaCrawlerDeployed() {
  console.log('🧪 Testing deployed Poppatea crawler...');
  
  try {
    const response = await axios.post(
      'https://zenradar-crawler-989787576521.europe-west3.run.app/crawl',
      {
        sites: ['poppatea']
      },
      {
        headers: {
          'Content-Type': 'application/json'
        },
        timeout: 60000 // Increase timeout for variant extraction
      }
    );
    
    console.log(`✅ Response Status: ${response.status}`);
    
    if (response.data.success) {
      const poppateaResults = response.data.results.find(r => r.site === 'poppatea');
      
      if (poppateaResults) {
        console.log(`\n🎯 Poppatea Crawler Results:`);
        console.log(`📦 Found ${poppateaResults.products.length} products`);
        console.log(`⏱️  Crawl time: ${poppateaResults.crawlTime}ms`);
        
        // Group products by base name to show variants
        const productGroups = {};
        poppateaResults.products.forEach(product => {
          // Extract base name (before the dash)
          const baseName = product.name.split(' - ')[0];
          
          if (!productGroups[baseName]) {
            productGroups[baseName] = [];
          }
          productGroups[baseName].push(product);
        });
        
        console.log(`\n📋 Product breakdown:`);
        Object.entries(productGroups).forEach(([baseName, variants]) => {
          console.log(`\n🍵 ${baseName}:`);
          variants.forEach((variant, index) => {
            console.log(`  ${index + 1}. ${variant.name}`);
            console.log(`     Price: ${variant.price} (Stock: ${variant.isInStock ? 'In Stock' : 'Out of Stock'})`);
            console.log(`     URL: ${variant.url}`);
          });
        });
        
        // Check if we have the expected 9 products (3 base × 3 variants)
        const expectedProducts = 9;
        const actualProducts = poppateaResults.products.length;
        
        if (actualProducts === expectedProducts) {
          console.log(`\n✅ SUCCESS: Found expected ${expectedProducts} products!`);
        } else {
          console.log(`\n⚠️  PARTIAL: Found ${actualProducts} products, expected ${expectedProducts}`);
          
          // Show which base products we have
          console.log(`📊 Base products found: ${Object.keys(productGroups).length}`);
          console.log(`📊 Variants per base product:`);
          Object.entries(productGroups).forEach(([baseName, variants]) => {
            console.log(`   - ${baseName}: ${variants.length} variants`);
          });
        }
        
      } else {
        console.log('❌ No Poppatea results in response');
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

testPoppateaCrawlerDeployed();
