# ZenRadar Crawler Test Suite

This directory contains comprehensive test files for all ZenRadar crawlers to ensure they work correctly and handle edge cases properly.

## 📋 Available Tests

- **Emeri Crawler** (`test_emeri_crawler.js`) - Tests emeri.co.uk matcha products
- **Horiishichimeien Crawler** (`test_horiishichimeien_crawler.js`) - Tests horiishichimeien.com matcha products  
- **Ippodo Tea Crawler** (`test_ippodo_tea_crawler.js`) - Tests global.ippodo-tea.co.jp matcha products
- **Marukyu Koyamaen Crawler** (`test_marukyu_koyamaen_crawler.js`) - Tests marukyu-koyamaen.co.jp matcha products
- **Matcha Karu Crawler** (`test_matcha_karu_crawler.js`) - Tests matchakaru.com matcha products
- **Nakamura Tokichi Crawler** (`test_nakamura_tokichi_crawler.js`) - Tests tokichi.jp matcha products
- **Poppatea Crawler** (`test_poppatea_crawler.js`) - Tests poppatea.com matcha products
- **Sazentea Crawler** (`test_sazentea_crawler.js`) - Tests sazentea.com matcha products
- **Sho Cha Crawler** (`test_sho_cha_crawler.js`) - Tests sho-cha.com matcha products
- **Yoshien Crawler** (`test_yoshien_crawler.js`) - Tests yoshien.com matcha products (with lazy loading support)

## 🚀 Running Tests

### Run All Crawler Tests
```bash
# Using npm script
npm run test:crawlers

# Direct node command
node test_all_crawlers.js
```

### Run Individual Crawler Tests
```bash
# Using npm scripts
npm run test:yoshien
npm run test:emeri

# Direct node commands
node test_yoshien_crawler.js
node test_emeri_crawler.js
```

### Run Specific Crawler Tests
```bash
# Run specific crawlers by name
node test_all_crawlers.js yoshien emeri
node test_all_crawlers.js nakamura-tokichi poppatea
```

### List Available Tests
```bash
# Using npm script
npm run test:list

# Direct command
node test_all_crawlers.js --list
```

### Get Help
```bash
node test_all_crawlers.js --help
```

## 🧪 What Each Test Covers

Each crawler test performs the following checks:

1. **Site Accessibility** - Verifies the target website is reachable
2. **Product Extraction** - Tests basic product data extraction (name, price, URL)
3. **Image Processing** - Validates image URL extraction and Firebase Storage integration
4. **Stock Detection** - Tests in-stock vs out-of-stock product identification
5. **Error Handling** - Ensures graceful failure handling

## 📊 Test Output

Each test provides detailed output including:
- ✅ Site accessibility status
- 📊 Number of products found
- 📋 Sample product data
- 🖼️ Image extraction statistics  
- 📈 Stock status breakdown
- ⏱️ Execution time

## 🎯 Special Test Cases

### Yoshien Crawler Test
The Yoshien test includes special handling for:
- **Lazy Loading** - Tests data-src attribute extraction
- **Base64 Placeholders** - Ensures base64 images are skipped
- **Magento Platform** - Validates Magento-specific selectors

### Master Test Runner
The `test_all_crawlers.js` provides:
- **Sequential Execution** - Runs tests one by one to avoid overwhelming servers
- **Detailed Reporting** - Generates JSON test reports with timestamps
- **Flexible Execution** - Run all tests, specific tests, or individual crawlers
- **Summary Statistics** - Shows pass/fail counts and execution times

## 📄 Test Reports

Test reports are automatically generated as JSON files:
- Format: `test-report-YYYY-MM-DDTHH-MM-SS.json`
- Contains: Summary statistics, individual test results, timestamps
- Location: Root crawler directory

## 🔧 Firebase Integration Testing

**Note**: These tests will show Firebase errors in the console because Firebase is not initialized in the test environment. This is expected behavior - the tests focus on:
- Image URL extraction (not Firebase storage)
- Product data parsing (not database storage)  
- Basic crawler functionality

To test Firebase integration, run the crawlers in the actual Cloud Run environment.

## 🐛 Troubleshooting

### Common Issues
- **Network timeouts**: Some sites may be slow to respond
- **Rate limiting**: Tests include delays between requests
- **Site changes**: Selectors may need updates if sites change structure

### Debug Individual Tests
Add `console.log` statements to specific test files for detailed debugging.

### Check Crawler Implementation  
If tests fail, check the corresponding crawler file in `src/crawlers/` for selector updates.

## 🔄 Continuous Integration

These tests can be integrated into CI/CD pipelines:
```bash
# In CI pipeline
npm install
npm run test:crawlers
```

## 📈 Performance Monitoring

Tests measure and report:
- Individual test execution time
- Overall test suite duration
- Success/failure rates
- Product extraction counts

This helps monitor crawler performance and detect regressions.
