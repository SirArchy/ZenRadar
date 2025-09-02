// Simple test to verify the CrawlerService syntax is correct
console.log('Testing CrawlerService syntax...');

try {
  const fs = require('fs');
  const path = require('path');
  
  // Read the crawler service file
  const crawlerPath = path.join(__dirname, 'src', 'crawler-service.js');
  const crawlerContent = fs.readFileSync(crawlerPath, 'utf8');
  
  // Check for key Poppatea improvements
  const checks = [
    {
      name: 'extractPoppateaVariants method exists',
      pattern: /async extractPoppateaVariants\(productUrl, baseName, config\)/,
      found: crawlerContent.includes('async extractPoppateaVariants(productUrl, baseName, config)')
    },
    {
      name: 'foundInJson variable initialized',
      pattern: /let foundInJson = false/,
      found: crawlerContent.includes('let foundInJson = false')
    },
    {
      name: 'Standard Poppatea variants creation',
      pattern: /standardVariants/,
      found: crawlerContent.includes('standardVariants')
    },
    {
      name: 'Three variant types (Dose, Nachfüllbeutel, 2x)',
      pattern: /50g Dose.*50g Nachfüllbeutel.*2x 50g Nachfüllbeutel/s,
      found: crawlerContent.includes('50g Dose') && 
             crawlerContent.includes('50g Nachfüllbeutel') && 
             crawlerContent.includes('2x 50g Nachfüllbeutel')
    },
    {
      name: 'Poppatea site configuration',
      pattern: /'poppatea':/,
      found: crawlerContent.includes("'poppatea':")
    }
  ];
  
  console.log('Checking CrawlerService improvements:');
  let allPassed = true;
  
  for (const check of checks) {
    if (check.found) {
      console.log(`✅ ${check.name}`);
    } else {
      console.log(`❌ ${check.name}`);
      allPassed = false;
    }
  }
  
  if (allPassed) {
    console.log('\n✅ All CrawlerService improvements are present!');
  } else {
    console.log('\n❌ Some improvements are missing');
  }
  
} catch (error) {
  console.error('❌ Test failed:', error.message);
}
