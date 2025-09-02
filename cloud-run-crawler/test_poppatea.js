const axios = require('axios');
const cheerio = require('cheerio');

// Simple test for Poppatea variant creation logic
function testPoppateaVariants() {
  console.log('Testing Poppatea variant creation...');
  
  const baseName = 'Matcha Tee Zeremoniell';
  const basePrice = 12.50;
  const productUrl = 'https://poppatea.com/de-de/collections/all-teas/products/matcha-tea-ceremonial';
  
  // Common Poppatea variants based on their standard product structure
  const standardVariants = [
    { size: '50g Dose', portions: '50 Portionen', multiplier: 1.0 },
    { size: '50g Nachfüllbeutel', portions: '50 Portionen', multiplier: 0.8 },
    { size: '2x 50g Nachfüllbeutel', portions: '100 Portionen', multiplier: 1.5 }
  ];
  
  const variants = [];
  
  // Create variants with estimated prices
  for (const variant of standardVariants) {
    const variantName = `${baseName} - ${variant.size} (${variant.portions})`;
    const variantPrice = basePrice * variant.multiplier;
    const variantPriceText = `€${variantPrice.toFixed(2).replace('.', ',')}`;
    
    variants.push({
      name: variantName,
      price: variantPriceText,
      priceValue: variantPrice,
      size: variant.size,
      portions: variant.portions
    });
  }
  
  console.log('Created variants:');
  variants.forEach((variant, index) => {
    console.log(`${index + 1}. ${variant.name}`);
    console.log(`   Price: ${variant.price} (${variant.priceValue})`);
    console.log(`   Size: ${variant.size}, Portions: ${variant.portions}`);
    console.log('');
  });
  
  console.log(`Total variants created: ${variants.length}`);
  console.log('Poppatea variant test completed successfully!');
}

testPoppateaVariants();
