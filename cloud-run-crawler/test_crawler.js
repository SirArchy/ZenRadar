const CrawlerService = require('./src/crawler-service');

// Simple test to verify the CrawlerService can be instantiated and methods exist
console.log('Testing CrawlerService instantiation...');

const mockFirestore = {
  collection: () => ({
    doc: () => ({
      set: () => Promise.resolve(),
      get: () => Promise.resolve({ exists: false })
    })
  })
};

const mockLogger = {
  info: console.log,
  warn: console.warn,
  error: console.error
};

try {
  const crawler = new CrawlerService(mockFirestore, mockLogger);
  console.log('✅ CrawlerService instantiated successfully');
  
  // Check if key methods exist
  const methodsToCheck = [
    'crawlSites',
    'crawlSite', 
    'extractPoppateaVariants',
    'parseVariantText',
    'generateProductId',
    'detectCategory'
  ];
  
  for (const method of methodsToCheck) {
    if (typeof crawler[method] === 'function') {
      console.log(`✅ Method ${method} exists`);
    } else {
      console.log(`❌ Method ${method} missing`);
    }
  }
  
  // Check if Poppatea site config exists
  const poppateaConfig = crawler.siteConfigs['poppatea'];
  if (poppateaConfig) {
    console.log('✅ Poppatea configuration found:');
    console.log(`   Name: ${poppateaConfig.name}`);
    console.log(`   Base URL: ${poppateaConfig.baseUrl}`);
    console.log(`   Category URL: ${poppateaConfig.categoryUrl}`);
  } else {
    console.log('❌ Poppatea configuration missing');
  }
  
  console.log('CrawlerService test completed successfully!');
  
} catch (error) {
  console.error('❌ CrawlerService test failed:', error.message);
  process.exit(1);
}
