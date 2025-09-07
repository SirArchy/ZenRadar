const PoppateaSpecializedCrawler = require('./src/crawlers/poppatea-crawler');

// Test the updated crawler logic
function testUpdatedCrawler() {
    const logger = {
        info: console.log,
        error: console.error,
        warn: console.warn
    };
    
    const crawler = new PoppateaSpecializedCrawler(logger);
    
    console.log('🧪 Testing updated Poppatea crawler logic...\n');
    
    // Test base title extraction
    console.log('📋 Testing base title extraction:');
    const testTitles = [
        'Matcha Tee - Zeremoniell - 50g Dose (50 Portionen)',
        'Matcha Tee mit Chai - Zeremoniell - 100g Nachfüllbeutel (100 Portionen)',
        'Hojicha Tea Powder - Hojichatee Pulver - 2x50g Nachfüllbeutel (100 Portionen)'
    ];
    
    testTitles.forEach(title => {
        const baseTitle = crawler.extractBaseTitle(title);
        console.log(`   "${title}" -> "${baseTitle}"`);
    });
    
    console.log('\n🔗 Testing product slug generation:');
    const baseTitles = [
        'Matcha Tee - Zeremoniell',
        'Matcha Tee mit Chai - Zeremoniell', 
        'Hojicha Tea Powder - Hojichatee Pulver'
    ];
    
    baseTitles.forEach(title => {
        const slug = crawler.getProductSlugFromTitle(title);
        console.log(`   "${title}" -> "${slug}"`);
    });
    
    console.log('\n🆔 Testing complete ID generation:');
    baseTitles.forEach(title => {
        const slug = crawler.getProductSlugFromTitle(title);
        const url = `https://poppatea.com/de-de/products/${slug}`;
        const productId = crawler.generateProductId(url, title);
        console.log(`   "${title}" -> ID: ${productId}`);
    });
    
    // Test variant creation
    console.log('\n🏭 Testing variant creation:');
    const mockVariant = {
        id: 12345,
        title: 'Matcha Tee - Zeremoniell - 50g Dose (50 Portionen)',
        price: 2495, // 24.95 EUR in cents
        available: true,
        product_id: 'matcha-ceremonial-123',
        inventory_quantity: 10,
        sku: 'MATCHA-CER-50G'
    };
    
    const baseTitle = 'Matcha Tee - Zeremoniell';
    const product = crawler.createVariantProduct(mockVariant, baseTitle);
    
    if (product) {
        console.log(`   Created product: ${product.id}`);
        console.log(`   Name: ${product.name}`);
        console.log(`   Price: ${product.price}`);
        console.log(`   URL: ${product.url}`);
        console.log(`   In Stock: ${product.isInStock}`);
    } else {
        console.log('   Failed to create product');
    }
}

testUpdatedCrawler();
