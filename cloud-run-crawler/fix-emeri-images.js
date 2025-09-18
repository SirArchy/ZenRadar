/**
 * Script to fix Emeri product imageUrl values
 * This script updates existing Emeri products in Firestore with the correct Firebase Storage URLs
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    storageBucket: 'zenradar-acb85.firebasestorage.app'
  });
}

const db = admin.firestore();
const storage = admin.storage();

async function fixEmeriImages() {
  console.log('🔧 Starting Emeri image URL fix...');
  
  try {
    // Get all Emeri products from Firestore
    const productsRef = db.collection('products');
    const querySnapshot = await productsRef.where('site', '==', 'enjoyemeri').get();
    
    console.log(`📋 Found ${querySnapshot.size} Emeri products to check`);
    
    let updatedCount = 0;
    let skippedCount = 0;
    let errorCount = 0;
    
    for (const doc of querySnapshot.docs) {
      const productData = doc.data();
      const productId = productData.id;
      
      try {
        // Skip if product already has an imageUrl
        if (productData.imageUrl && productData.imageUrl.includes('storage.googleapis.com')) {
          console.log(`✅ ${productId}: Already has Firebase Storage URL`);
          skippedCount++;
          continue;
        }
        
        // Check if image exists in Firebase Storage
        const fileName = `product-images/enjoyemeri/${productId}.jpg`;
        const file = storage.bucket().file(fileName);
        
        const [exists] = await file.exists();
        
        if (exists) {
          // Construct the public URL
          const bucketName = storage.bucket().name;
          const cleanBucketName = bucketName.replace('.firebasestorage.app', '');
          const publicUrl = `https://storage.googleapis.com/${cleanBucketName}.firebasestorage.app/${fileName}`;
          
          // Update the product document
          await doc.ref.update({
            imageUrl: publicUrl,
            lastUpdated: new Date()
          });
          
          console.log(`🔧 ${productId}: Updated with image URL`);
          updatedCount++;
        } else {
          console.log(`❌ ${productId}: No image found in storage`);
          errorCount++;
        }
        
      } catch (error) {
        console.error(`❌ ${productId}: Error processing -`, error.message);
        errorCount++;
      }
    }
    
    console.log('\n📊 Summary:');
    console.log(`✅ Updated: ${updatedCount} products`);
    console.log(`⏭️ Skipped: ${skippedCount} products (already have URLs)`);
    console.log(`❌ Errors: ${errorCount} products`);
    console.log('🎉 Emeri image URL fix completed!');
    
  } catch (error) {
    console.error('❌ Failed to fix Emeri images:', error);
  }
}

// Run the fix
fixEmeriImages().then(() => {
  console.log('✅ Script completed');
  process.exit(0);
}).catch(error => {
  console.error('❌ Script failed:', error);
  process.exit(1);
});
