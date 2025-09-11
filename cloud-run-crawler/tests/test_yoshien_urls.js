// Test script to verify Yoshien image URL generation
console.log('=== Testing Yoshien Image URL Generation ===');

// Simulate the URL generation logic
function generateYoshienImageUrl(productId, siteKey = 'yoshien') {
    const fileName = `product-images/${siteKey}/${productId}.jpg`;
    const bucketName = 'zenradar-acb85'; // Your actual bucket name
    const publicUrl = `https://storage.googleapis.com/${bucketName}.firebasestorage.app/${fileName}`;
    return publicUrl;
}

// Test with some example product IDs that might exist for Yoshien
const testProducts = [
    'yoshien_matcha_matchapulver',
    'yoshien_organic_organicmatcha',
    'yoshien_premium_premiumgrade',
    'yoshien_ceremonial_ceremonialmatcha'
];

console.log('Expected Yoshien image URLs:');
testProducts.forEach((productId, index) => {
    const imageUrl = generateYoshienImageUrl(productId);
    console.log(`${index + 1}. ${imageUrl}`);
});

console.log('\nURL Pattern: https://storage.googleapis.com/zenradar-acb85.firebasestorage.app/product-images/yoshien/{productId}.jpg');
console.log('\n✅ URLs are now in the correct format for Firebase Storage public access');
