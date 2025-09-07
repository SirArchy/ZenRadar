const admin = require('firebase-admin');
const serviceAccount = require('./zenradar-firebase-adminsdk-kl1v2-8b476f9b4e.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkPoppateaProducts() {
  try {
    // Search for the specific products mentioned
    const products = [
      'matchateaceremonial_matchateezeremoniell',
      'matchateawithchaiceremonial_matchateemitchaizere', 
      'hojichateapowder_hojichateepulver'
    ];
    
    console.log('🔍 Checking Poppatea products...\n');
    
    for (const productId of products) {
      console.log(`Looking for products containing: ${productId}`);
      
      // Query all Poppatea products
      const querySnapshot = await db.collection('products')
        .where('site', '==', 'poppatea')
        .get();
      
      const matchingProducts = [];
      querySnapshot.forEach(doc => {
        const data = doc.data();
        const docId = doc.id.toLowerCase();
        const productName = (data.name || '').toLowerCase();
        
        if (docId.includes(productId.toLowerCase()) || productName.includes(productId.toLowerCase())) {
          matchingProducts.push({
            id: doc.id,
            name: data.name,
            isInStock: data.isInStock,
            price: data.price
          });
        }
      });
      
      if (matchingProducts.length > 0) {
        console.log(`✅ Found ${matchingProducts.length} variants:`);
        matchingProducts.forEach(product => {
          console.log(`   - ${product.id}`);
          console.log(`     Name: ${product.name}`);
          console.log(`     Stock: ${product.isInStock}`);
          console.log(`     Price: ${product.price}`);
        });
      } else {
        console.log('❌ No variants found');
      }
      console.log('');
    }
    
    // Also show all Poppatea products for reference
    console.log('📋 All Poppatea products in Firestore:');
    const allSnapshot = await db.collection('products')
      .where('site', '==', 'poppatea')
      .get();
    
    console.log(`Found ${allSnapshot.size} total Poppatea products:`);
    allSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`   - ${doc.id} (${data.name})`);
    });
    
  } catch (error) {
    console.error('Error:', error);
  }
  
  process.exit(0);
}

checkPoppateaProducts();
