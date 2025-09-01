const axios = require('axios');
const cheerio = require('cheerio');

// Import the specialized crawlers
const ShoChaSpecializedCrawler = require('./src/crawlers/sho-cha-crawler');
const PoppateaSpecializedCrawler = require('./src/crawlers/poppatea-crawler');
const SiteCrawlerFactory = require('./src/crawlers/site-crawler-factory');

/**
 * Test script for specialized crawlers
 */
async function testSpecializedCrawlers() {
  console.log('🧪 Testing Specialized Crawlers');
  console.log('================================\n');

  const mockLogger = {
    info: (msg, data) => console.log(`ℹ️  ${msg}`, data || ''),
    error: (msg, data) => console.error(`❌ ${msg}`, data || ''),
    warn: (msg, data) => console.warn(`⚠️  ${msg}`, data || '')
  };

  // Test 1: Sho-Cha Crawler
  console.log('1️⃣  Testing Sho-Cha Specialized Crawler');
  console.log('-----------------------------------');
  
  try {
    const shoChaConfig = {
      name: 'Sho-Cha',
      baseUrl: 'https://www.sho-cha.com',
      categoryUrl: 'https://www.sho-cha.com/teeshop'
    };

    const shoChaResult = await testShoChaSpecialized(shoChaConfig, mockLogger);
    console.log(`✅ Sho-Cha products found: ${shoChaResult.products.length}`);
    
    // Check if products have prices
    const productsWithPrices = shoChaResult.products.filter(p => p.price && p.priceValue);
    console.log(`💰 Products with prices: ${productsWithPrices.length}`);
    
    if (productsWithPrices.length > 0) {
      console.log(`💡 Sample product with price: ${productsWithPrices[0].name} - ${productsWithPrices[0].price}`);
    }
    
  } catch (error) {
    console.error('❌ Sho-Cha test failed:', error.message);
  }

  console.log('\n');

  // Test 2: Poppatea Crawler
  console.log('2️⃣  Testing Poppatea Specialized Crawler');
  console.log('------------------------------------');
  
  try {
    const poppateaConfig = {
      name: 'Poppatea',
      baseUrl: 'https://poppatea.com',
      categoryUrl: 'https://poppatea.com/collections/all'
    };

    const poppateaResult = await testPoppateaSpecialized(poppateaConfig, mockLogger);
    console.log(`✅ Poppatea products found: ${poppateaResult.products.length}`);
    
    // Check for variants
    const productsWithVariants = poppateaResult.products.filter(p => p.variants && p.variants.length > 0);
    console.log(`🔗 Products with variants: ${productsWithVariants.length}`);
    
    if (productsWithVariants.length > 0) {
      console.log(`💡 Sample variants: ${productsWithVariants[0].variants.map(v => v.title).join(', ')}`);
    }
    
  } catch (error) {
    console.error('❌ Poppatea test failed:', error.message);
  }

  console.log('\n');

  // Test 3: Factory Pattern
  console.log('3️⃣  Testing Site Crawler Factory');
  console.log('------------------------------');
  
  try {
    const hasShoCha = SiteCrawlerFactory.hasSpecializedCrawler('sho-cha');
    const hasPoppatea = SiteCrawlerFactory.hasSpecializedCrawler('poppatea');
    const hasGeneric = SiteCrawlerFactory.hasSpecializedCrawler('tokichi');
    
    console.log(`✅ Sho-Cha specialized: ${hasShoCha}`);
    console.log(`✅ Poppatea specialized: ${hasPoppatea}`);
    console.log(`✅ Tokichi generic: ${hasGeneric}`);
    
    if (hasShoCha) {
      const shoCrawler = SiteCrawlerFactory.getCrawler('sho-cha', mockLogger);
      console.log(`✅ Sho-Cha crawler instantiated: ${shoCrawler.constructor.name}`);
    }
    
    if (hasPoppatea) {
      const poppaCrawler = SiteCrawlerFactory.getCrawler('poppatea', mockLogger);
      console.log(`✅ Poppatea crawler instantiated: ${poppaCrawler.constructor.name}`);
    }
    
  } catch (error) {
    console.error('❌ Factory test failed:', error.message);
  }

  console.log('\n🏁 Testing completed!');
}

async function testShoChaSpecialized(config, logger) {
  const crawler = new ShoChaSpecializedCrawler(logger);
  return await crawler.crawl(config.categoryUrl, config);
}

async function testPoppateaSpecialized(config, logger) {
  const crawler = new PoppateaSpecializedCrawler(logger);
  return await crawler.crawl(config.categoryUrl, config);
}

// Run the tests
if (require.main === module) {
  testSpecializedCrawlers().catch(console.error);
}

module.exports = { testSpecializedCrawlers };
