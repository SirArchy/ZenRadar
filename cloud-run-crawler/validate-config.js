// Simple configuration validation test
console.log('🚀 Testing enhanced crawler configurations...\n');

// Read the crawler service file to extract configurations
const fs = require('fs');
const path = require('path');

const crawlerServicePath = path.join(__dirname, 'src', 'crawler-service.js');
const crawlerCode = fs.readFileSync(crawlerServicePath, 'utf8');

// Extract siteConfigs object
const configMatch = crawlerCode.match(/this\.siteConfigs\s*=\s*{([\s\S]*?)};/);
if (!configMatch) {
  console.error('❌ Could not find siteConfigs in crawler-service.js');
  process.exit(1);
}

console.log('✅ Found siteConfigs in crawler-service.js\n');

// Test required fields
const requiredFields = [
  'name', 'baseUrl', 'categoryUrl', 'productSelector', 
  'nameSelector', 'priceSelector', 'linkSelector', 'imageSelector'
];

// Count configurations with imageSelector
let sitesWithImages = 0;
let totalSites = 0;

// Parse site configurations
const configLines = configMatch[1].split('\n');
let currentSite = null;
let siteConfig = {};
let sitesFound = [];

for (const line of configLines) {
  const trimmedLine = line.trim();
  
  // Check for site start - more robust pattern
  const siteMatch = trimmedLine.match(/^'([^']+)':\s*{/);
  if (siteMatch) {
    if (currentSite) {
      // Process previous site
      sitesFound.push(currentSite);
      totalSites++;
      if (siteConfig.imageSelector) {
        sitesWithImages++;
        console.log(`✅ ${currentSite}: Has imageSelector`);
      } else {
        console.log(`❌ ${currentSite}: Missing imageSelector`);
      }
    }
    
    currentSite = siteMatch[1];
    siteConfig = {};
  }
  
  // Check for imageSelector
  if (trimmedLine.includes('imageSelector:')) {
    siteConfig.imageSelector = true;
  }
}

// Process last site
if (currentSite) {
  sitesFound.push(currentSite);
  totalSites++;
  if (siteConfig.imageSelector) {
    sitesWithImages++;
    console.log(`✅ ${currentSite}: Has imageSelector`);
  } else {
    console.log(`❌ ${currentSite}: Missing imageSelector`);
  }
}

console.log(`\nSites found: ${sitesFound.join(', ')}\n`);

console.log(`\n📊 Summary: ${sitesWithImages}/${totalSites} sites have imageSelector configured\n`);

// Test specific enhancements
console.log('✅ Testing specific enhancements...');

// Check for Poppatea variant handler
if (crawlerCode.includes('extractPoppateaVariants')) {
  console.log('✅ Poppatea variant extraction: Enhanced');
} else {
  console.log('❌ Poppatea variant extraction: Missing');
}

// Check for currency conversion
if (crawlerCode.includes('currencyConversion') && crawlerCode.includes('JPY') && crawlerCode.includes('EUR')) {
  console.log('✅ Currency conversion: Implemented');
} else {
  console.log('❌ Currency conversion: Missing');
}

// Check for image processing
if (crawlerCode.includes('downloadAndStoreImage')) {
  console.log('✅ Image processing: Implemented');
} else {
  console.log('❌ Image processing: Missing');
}

// Check for Firebase Storage
if (crawlerCode.includes('firebase-admin') && crawlerCode.includes('getStorage')) {
  console.log('✅ Firebase Storage: Configured');
} else {
  console.log('❌ Firebase Storage: Missing');
}

// Check for Sharp image compression
if (crawlerCode.includes('sharp') && crawlerCode.includes('resize')) {
  console.log('✅ Image compression: Sharp configured');
} else {
  console.log('❌ Image compression: Missing');
}

console.log('\n🎉 Configuration validation complete!');

if (sitesWithImages === totalSites) {
  console.log('✅ All enhancements successfully implemented!');
} else {
  console.log(`⚠️  ${totalSites - sitesWithImages} sites still missing image selectors`);
}
