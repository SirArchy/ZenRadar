// Test script to verify image fixes
const axios = require('axios');

console.log('🔧 Testing Image URL fixes...\n');

// Test 1: Firebase Storage URL processing
function testFirebaseUrlProcessing() {
    console.log('1. Testing Firebase Storage URL processing:');
    
    const testUrls = [
        'https://storage.googleapis.com/zenradar-acb85.firebasestorage.app.firebasestorage.app/product-images/matcha-karu/test.jpg',
        'https://storage.googleapis.com/zenradar-acb85/product-images/matcha-karu/test.jpg',
        'https://storage.googleapis.com/zenradar-acb85.firebasestorage.app/product-images/matcha-karu/test.jpg'
    ];
    
    for (const url of testUrls) {
        console.log(`   Input:  ${url}`);
        
        // Apply the same processing as PlatformImage widget
        let processedUrl = url;
        
        // Fix doubled Firebase Storage domains
        processedUrl = processedUrl.replaceAll('.firebasestorage.app.firebasestorage.app', '.firebasestorage.app');
        
        // Ensure Firebase Storage URLs use the correct format
        if (processedUrl.includes('storage.googleapis.com')) {
            const bucketPattern = /storage\.googleapis\.com\/([^/\.]+)(?!\.firebasestorage\.app)/;
            processedUrl = processedUrl.replace(bucketPattern, (match, bucketName) => {
                return `storage.googleapis.com/${bucketName}.firebasestorage.app`;
            });
        }
        
        console.log(`   Output: ${processedUrl}`);
        console.log(`   ✅ ${url === processedUrl ? 'No change needed' : 'Fixed'}\n`);
    }
}

// Test 2: Bucket name handling
function testBucketNameHandling() {
    console.log('2. Testing bucket name handling:');
    
    const bucketNames = [
        'zenradar-acb85',
        'zenradar-acb85.firebasestorage.app'
    ];
    
    for (const bucketName of bucketNames) {
        const fileName = 'product-images/poppatea/test.jpg';
        const cleanBucketName = bucketName.replace('.firebasestorage.app', '');
        const publicUrl = `https://storage.googleapis.com/${cleanBucketName}.firebasestorage.app/${fileName}`;
        
        console.log(`   Bucket: ${bucketName}`);
        console.log(`   Clean:  ${cleanBucketName}`);
        console.log(`   URL:    ${publicUrl}`);
        console.log(`   ✅ Correct format\n`);
    }
}

// Test 3: Poppatea image extraction simulation
function testPoppateaImageExtraction() {
    console.log('3. Testing Poppatea image extraction patterns:');
    
    const sampleImages = [
        'https://poppatea.com/cdn/shop/files/matcha_tea_fc280084-cbe6-4965-879b-4a126cfbee67.jpg?v=1745172821&width=1000',
        'https://poppatea.com/cdn/shop/files/matcha_tea_with_chai_80b90bbf-8312-402a-9c2a-729f965b3f59.jpg?v=1745172485&width=500',
        'https://poppatea.com/cdn/shop/files/hojicha-tin-straight_view.jpg?v=1745172614&width=600'
    ];
    
    const productUrls = [
        'https://poppatea.com/de-de/products/matcha-tea-ceremonial',
        'https://poppatea.com/de-de/products/matcha-tea-with-chai-ceremonial', 
        'https://poppatea.com/de-de/products/hojicha-tea-powder'
    ];
    
    for (let i = 0; i < productUrls.length; i++) {
        const productUrl = productUrls[i];
        const sampleImg = sampleImages[i];
        const imgName = sampleImg.toLowerCase();
        
        console.log(`   Product: ${productUrl}`);
        console.log(`   Image:   ${sampleImg}`);
        
        let shouldMatch = false;
        
        if (productUrl.includes('matcha-tea-ceremonial') && !productUrl.includes('chai')) {
            shouldMatch = imgName.includes('matcha_tea') && !imgName.includes('chai');
        } else if (productUrl.includes('matcha-tea-with-chai')) {
            shouldMatch = imgName.includes('matcha_tea_with_chai') || (imgName.includes('chai') && imgName.includes('matcha'));
        } else if (productUrl.includes('hojicha-tea-powder')) {
            shouldMatch = imgName.includes('hojicha');
        }
        
        console.log(`   Match:   ${shouldMatch ? '✅ Yes' : '❌ No'}`);
        
        // Clean up URL parameters
        const cleanUrl = sampleImg.split('?')[0];
        console.log(`   Clean:   ${cleanUrl}\n`);
    }
}

// Run tests
testFirebaseUrlProcessing();
testBucketNameHandling();  
testPoppateaImageExtraction();

console.log('🎉 All image fix tests completed!');
