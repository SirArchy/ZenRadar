const axios = require('axios');
const cheerio = require('cheerio');

async function testShoChaImproved() {
  console.log('🍃 Testing Improved Sho-Cha Link Detection...');
  
  const userAgent = 'ZenRadar Bot 1.0 (+https://zenradar.app)';
  const requestConfig = {
    timeout: 30000,
    headers: {
      'User-Agent': userAgent,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9,de;q=0.8,sv;q=0.7',
      'Accept-Encoding': 'gzip, deflate, br',
      'DNT': '1',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
    }
  };
  
  try {
    const response = await axios.get('https://www.sho-cha.com/teeshop', requestConfig);
    const $ = cheerio.load(response.data);
    
    console.log('✅ Page loaded successfully');
    
    // Find all teeshop links first
    const allTeeshopLinks = $('a[href*="/teeshop/"]');
    console.log(`📋 Found ${allTeeshopLinks.length} total teeshop links`);
    
    allTeeshopLinks.slice(0, 10).each((index, link) => {
      const $link = $(link);
      const href = $link.attr('href');
      const text = $link.text().trim();
      console.log(`  Link ${index + 1}: ${href} - "${text}"`);
    });
    
    // Find h1 elements with matcha
    const h1Elements = $('h1');
    console.log(`\n📋 Found ${h1Elements.length} h1 elements`);
    
    const matchaH1s = [];
    h1Elements.each((index, element) => {
      const text = $(element).text().trim();
      if (text && text.toLowerCase().includes('matcha')) {
        matchaH1s.push({ element: $(element), text });
      }
    });
    
    console.log(`🍵 Found ${matchaH1s.length} h1 elements containing "matcha"`);
    
    // Test improved link detection strategies
    for (let i = 0; i < Math.min(matchaH1s.length, 3); i++) {
      const { element: $h1, text } = matchaH1s[i];
      console.log(`\n--- Testing: ${text} ---`);
      
      let foundLink = null;
      
      // Strategy 1: Immediate parent
      const immediateParent = $h1.parent();
      let teeshopLink = immediateParent.find('a[href*="/teeshop/"]').first();
      if (teeshopLink.length) {
        foundLink = teeshopLink.attr('href');
        console.log(`✅ Strategy 1 (immediate parent): ${foundLink}`);
      } else {
        console.log(`❌ Strategy 1: Not found in immediate parent`);
      }
      
      // Strategy 2: Wider container
      if (!foundLink) {
        const section = $h1.closest('section, div, article, .product-container, .item-container');
        teeshopLink = section.find('a[href*="/teeshop/"]').first();
        if (teeshopLink.length) {
          foundLink = teeshopLink.attr('href');
          console.log(`✅ Strategy 2 (wider container): ${foundLink}`);
        } else {
          console.log(`❌ Strategy 2: Not found in wider container`);
        }
      }
      
      // Strategy 3: Siblings
      if (!foundLink) {
        teeshopLink = $h1.siblings().find('a[href*="/teeshop/"]').first();
        if (teeshopLink.length) {
          foundLink = teeshopLink.attr('href');
          console.log(`✅ Strategy 3 (siblings): ${foundLink}`);
        } else {
          console.log(`❌ Strategy 3: Not found in siblings`);
        }
      }
      
      // Strategy 4: Next/Previous elements
      if (!foundLink) {
        const nextElement = $h1.next();
        teeshopLink = nextElement.find('a[href*="/teeshop/"]').first();
        
        if (!teeshopLink.length) {
          const prevElement = $h1.prev();
          teeshopLink = prevElement.find('a[href*="/teeshop/"]').first();
        }
        
        if (teeshopLink.length) {
          foundLink = teeshopLink.attr('href');
          console.log(`✅ Strategy 4 (next/prev): ${foundLink}`);
        } else {
          console.log(`❌ Strategy 4: Not found in next/prev`);
        }
      }
      
      // Strategy 5: Name matching
      if (!foundLink) {
        const nameSlug = text.toLowerCase().replace(/[^a-z0-9]/g, '');
        console.log(`  Name slug: "${nameSlug}"`);
        
        allTeeshopLinks.each((idx, link) => {
          const href = $(link).attr('href');
          const linkSlug = href.replace('/teeshop/', '').replace(/[^a-z0-9]/g, '');
          const linkText = $(link).text().toLowerCase().replace(/[^a-z0-9]/g, '');
          
          if ((linkSlug.includes(nameSlug.substring(0, 8)) || 
               nameSlug.includes(linkSlug.substring(0, 8))) ||
              (linkText.includes(nameSlug.substring(0, 8)) || 
               nameSlug.includes(linkText.substring(0, 8)))) {
            foundLink = href;
            console.log(`✅ Strategy 5 (name matching): ${foundLink}`);
            console.log(`    Link text: "${$(link).text().trim()}"`);
            console.log(`    Link slug: "${linkSlug}"`);
            return false; // Break
          }
        });
        
        if (!foundLink) {
          console.log(`❌ Strategy 5: No name match found`);
        }
      }
      
      if (foundLink) {
        console.log(`🎯 FINAL RESULT: https://www.sho-cha.com${foundLink}`);
      } else {
        console.log(`💔 NO LINK FOUND for "${text}"`);
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

testShoChaImproved();
