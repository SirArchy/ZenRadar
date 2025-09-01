const PoppateaSpecializedCrawler = require('./src/crawlers/poppatea-crawler');
const axios = require('axios');

// Mock logger for testing
const mockLogger = {
  info: (msg, meta) => console.log(`[INFO] ${msg}`, meta || ''),
  warn: (msg, meta) => console.log(`[WARN] ${msg}`, meta || ''),
  error: (msg, meta) => console.log(`[ERROR] ${msg}`, meta || '')
};

async function testPoppateaImages() {
  console.log('🖼️  Testing Poppatea Image URLs\n');
  
  const crawler = new PoppateaSpecializedCrawler(mockLogger);
  
  try {
    const result = await crawler.crawl('https://poppatea.com/de-de/collections/all-teas');
    
    console.log(`📦 Total products found: ${result.products.length}\n`);
    
    // Check image URLs for each product
    for (let i = 0; i < result.products.length; i++) {
      const product = result.products[i];
      console.log(`🔍 Product ${i + 1}: ${product.name}`);
      console.log(`   Image URL: ${product.imageUrl || 'NO IMAGE URL'}`);
      
      if (product.imageUrl) {
        try {
          // Test if image URL is accessible
          const response = await axios.head(product.imageUrl, {
            timeout: 10000,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
          });
          
          const contentType = response.headers['content-type'];
          const contentLength = response.headers['content-length'];
          
          console.log(`   ✅ Image accessible: ${response.status} ${response.statusText}`);
          console.log(`   📄 Content-Type: ${contentType}`);
          console.log(`   📏 Size: ${contentLength ? `${Math.round(contentLength / 1024)}KB` : 'Unknown'}`);
          
          // Check if it's actually an image
          if (contentType && contentType.startsWith('image/')) {
            console.log(`   🎨 Valid image format: ${contentType.split('/')[1]}`);
          } else {
            console.log(`   ❌ Not an image: ${contentType}`);
          }
          
        } catch (error) {
          console.log(`   ❌ Image request failed: ${error.message}`);
          
          // Try alternative URL formats
          if (product.imageUrl.startsWith('//')) {
            const httpsUrl = 'https:' + product.imageUrl;
            console.log(`   🔄 Trying HTTPS version: ${httpsUrl}`);
            
            try {
              const altResponse = await axios.head(httpsUrl, {
                timeout: 10000,
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                }
              });
              console.log(`   ✅ Alternative URL works: ${altResponse.status}`);
            } catch (altError) {
              console.log(`   ❌ Alternative URL also failed: ${altError.message}`);
            }
          }
        }
      } else {
        console.log(`   ⚠️  No image URL found for this product`);
      }
      
      console.log(''); // Empty line for readability
    }
    
  } catch (error) {
    console.log(`❌ Error testing images:`, error.message);
  }
}

testPoppateaImages().catch(console.error);
