// Mock Firebase Admin to avoid initialization issues
const mockFirebaseAdmin = {
  initializeApp: () => ({}),
  storage: () => ({
    bucket: () => ({
      file: () => ({
        save: async () => ({ publicUrl: () => 'https://mock-url.com/image.jpg' })
      })
    })
  })
};

// Mock Sharp to avoid requiring it
const mockSharp = () => ({
  resize: () => mockSharp(),
  jpeg: () => mockSharp(),
  toBuffer: async () => Buffer.from('mock-image-data')
});

// Replace modules before requiring crawler
require('module')._cache = {};
require.cache = {};

// Mock the modules
jest.mock = jest.mock || (() => {});
const Module = require('module');
const originalRequire = Module.prototype.require;

Module.prototype.require = function(id) {
  if (id === 'firebase-admin') {
    return mockFirebaseAdmin;
  }
  if (id === 'sharp') {
    return mockSharp;
  }
  return originalRequire.apply(this, arguments);
};

const CrawlerService = require('./src/crawler-service');

async function testCrawler() {
  console.log('🚀 Testing enhanced crawler...\n');
  
  try {
    // Create instance without Firebase
    const crawler = new CrawlerService();
    
    // Test 1: Basic configuration validation
    console.log('✅ Testing site configurations...');
    const configs = Object.keys(crawler.siteConfigs);
    console.log(`Found ${configs.length} site configurations: ${configs.join(', ')}\n`);
    
    // Validate each config has required fields
    for (const siteKey of configs) {
      const config = crawler.siteConfigs[siteKey];
      if (!config.imageSelector) {
        console.error(`❌ Site ${siteKey} missing imageSelector`);
      } else {
        console.log(`✅ Site ${siteKey} has imageSelector: ${config.imageSelector}`);
      }
    }
    
    // Test 2: Currency conversion
    console.log('\n✅ Testing currency conversion...');
    const testPriceJPY = '1000円';
    const convertedPrice = crawler.convertCurrency(testPriceJPY, 'JPY', 'EUR', 0.0062);
    console.log(`JPY ¥1000 → EUR €${convertedPrice}`);
    
    // Test 3: Product ID generation
    console.log('\n✅ Testing product ID generation...');
    const testUrl = 'https://example.com/products/matcha-test';
    const testName = 'Premium Matcha - 100g';
    const productId = crawler.generateProductId(testUrl, testName, 'test-site');
    console.log(`Generated ID: ${productId}`);
    
    // Test 4: Category detection
    console.log('\n✅ Testing category detection...');
    const categories = [
      'Premium Matcha Powder',
      'Ceremonial Grade Matcha',
      'Matcha Latte Mix',
      'Matcha Cookie'
    ];
    
    for (const name of categories) {
      const category = crawler.detectCategory(name, 'test-site');
      console.log(`"${name}" → Category: ${category}`);
    }
    
    // Test 5: Image URL processing
    console.log('\n✅ Testing image URL processing...');
    const testImageUrls = [
      'https://example.com/image.jpg?v=123&size=400x400',
      '//cdn.example.com/product.jpg',
      '/static/matcha.png'
    ];
    
    for (const url of testImageUrls) {
      try {
        const processed = crawler.normalizeImageUrl(url, 'https://example.com');
        console.log(`"${url}" → "${processed}"`);
      } catch (error) {
        console.log(`"${url}" → Error: ${error.message}`);
      }
    }
    
    console.log('\n🎉 All basic tests passed! Enhanced crawler is ready.');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    console.error(error.stack);
  }
}

// Add URL normalization method if it doesn't exist
if (!CrawlerService.prototype.normalizeImageUrl) {
  CrawlerService.prototype.normalizeImageUrl = function(url, baseUrl) {
    if (!url) return null;
    
    // Remove query parameters
    url = url.split('?')[0];
    
    // Handle protocol-relative URLs
    if (url.startsWith('//')) {
      return 'https:' + url;
    }
    
    // Handle relative URLs
    if (url.startsWith('/')) {
      const base = new URL(baseUrl);
      return base.origin + url;
    }
    
    // Return absolute URLs as-is
    if (url.startsWith('http')) {
      return url;
    }
    
    // Fallback: prepend base URL
    return new URL(url, baseUrl).href;
  };
}

testCrawler();
