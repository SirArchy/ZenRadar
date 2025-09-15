const axios = require('axios');

async function testShoChaImages() {
    // Test a few sample image URLs from the Sho-Cha crawler output
    const testUrls = [
        'https://images.squarespace-cdn.com/content/v1/5cf01ddcea4afa0001987bff/1692177910561-D85M9AMSEL1RFH5RU6E8/Amai+Matcha+Great+Taste+Winner+Japan+Gr%C3%BCntee.jpg',
        'https://images.squarespace-cdn.com/content/v1/5cf01ddcea4afa0001987bff/c60ca63c-2fbb-4e58-9c53-983982539bb7/Limited+Matcha+Uji+Cermonial+Grade+Kyoto+Matchapulver+Great+Taste+Gewinner.jpg',
        'https://images.squarespace-cdn.com/content/v1/5cf01ddcea4afa0001987bff/1600764126237-D2RGXC6U46PBCJQ3NTTR/Matchadose+P2.jpg'
    ];
    
    for (const url of testUrls) {
        try {
            console.log(`\nTesting image: ${url.substring(0, 80)}...`);
            const response = await axios.head(url, {
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                }
            });
            
            console.log(`✅ Status: ${response.status}`);
            console.log(`Content-Type: ${response.headers['content-type']}`);
            console.log(`Content-Length: ${response.headers['content-length']}`);
            
            // Try to decode the URL properly
            const decodedUrl = decodeURIComponent(url);
            console.log(`Decoded URL: ${decodedUrl.substring(0, 80)}...`);
            
        } catch (error) {
            console.log(`❌ Error: ${error.message}`);
        }
    }
}

testShoChaImages();
