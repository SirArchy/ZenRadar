const axios = require('axios');
const cheerio = require('cheerio');

async function checkProductPageImagesDetailed() {
  console.log('🔍 Checking Individual Product Page Images in Detail\n');
  
  const productUrls = [
    {
      name: 'Matcha Tea Ceremonial',
      url: 'https://poppatea.com/de-de/collections/all-teas/products/matcha-tea-ceremonial'
    },
    {
      name: 'Matcha Tea with Chai Ceremonial', 
      url: 'https://poppatea.com/de-de/collections/all-teas/products/matcha-tea-with-chai-ceremonial'
    },
    {
      name: 'Hojicha Tea Powder',
      url: 'https://poppatea.com/de-de/collections/all-teas/products/hojicha-tea-powder'
    }
  ];

  const requestConfig = {
    timeout: 30000,
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5'
    }
  };

  for (const product of productUrls) {
    console.log(`📦 ${product.name}`);
    console.log(`🔗 URL: ${product.url}`);
    
    try {
      const response = await axios.get(product.url, requestConfig);
      const $ = cheerio.load(response.data);
      
      // Check multiple image selectors
      const imageSelectors = [
        '.product__media img',
        '.product-single__photos img', 
        '.product__photo img',
        '.product-main-image img',
        'img[src*="product"]',
        'img[src*="cdn/shop"]',
        '.product img',
        'img'
      ];
      
      const foundImages = new Set();
      
      for (const selector of imageSelectors) {
        const images = $(selector);
        console.log(`   🖼️  Found ${images.length} images with selector: ${selector}`);
        
        images.each((idx, img) => {
          let src = $(img).attr('src') || $(img).attr('data-src') || $(img).attr('data-original');
          if (src) {
            // Normalize URL
            if (src.startsWith('//')) {
              src = 'https:' + src;
            } else if (src.startsWith('/')) {
              src = 'https://poppatea.com' + src;
            }
            
            // Filter out tiny images and icons
            const alt = $(img).attr('alt') || '';
            const isProductImage = src.includes('cdn/shop') && 
                                  !src.includes('icon') && 
                                  !src.includes('logo') &&
                                  !alt.toLowerCase().includes('icon') &&
                                  !alt.toLowerCase().includes('logo');
            
            if (isProductImage) {
              foundImages.add({
                src: src,
                alt: alt,
                selector: selector
              });
            }
          }
        });
      }
      
      console.log(`   ✅ Unique product images found: ${foundImages.size}`);
      
      Array.from(foundImages).forEach((img, idx) => {
        console.log(`     ${idx + 1}. ${img.src}`);
        console.log(`        Alt: "${img.alt}"`);
        console.log(`        From: ${img.selector}`);
      });
      
      // Look for variant-specific images in JSON
      console.log(`   🔍 Checking for variant images in JSON...`);
      let variantImagesFound = false;
      
      $('script').each((idx, script) => {
        const content = $(script).html();
        if (content && content.includes('"variants"') && content.includes('"featured_image"')) {
          try {
            const variantMatches = content.match(/"variants"\s*:\s*\[([^\]]*)\]/);
            if (variantMatches) {
              const variantArray = JSON.parse('[' + variantMatches[1] + ']');
              
              variantArray.forEach((variant, vIdx) => {
                if (variant.featured_image) {
                  console.log(`     Variant ${vIdx + 1}: ${variant.title}`);
                  console.log(`       Image: ${variant.featured_image}`);
                  variantImagesFound = true;
                }
              });
            }
          } catch (e) {
            // Continue
          }
        }
      });
      
      if (!variantImagesFound) {
        console.log(`     ❌ No variant-specific images found in JSON`);
      }
      
    } catch (error) {
      console.log(`   ❌ Error: ${error.message}`);
    }
    
    console.log(''); // Empty line for readability
  }
}

checkProductPageImagesDetailed().catch(console.error);
