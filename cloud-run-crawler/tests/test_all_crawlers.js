/**
 * Master Test Runner for all ZenRadar Crawlers
 * Executes comprehensive tests for all crawler implementations
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

class CrawlerTestRunner {
    constructor() {
        this.testFiles = [
            'test_emeri_crawler.js',
            'test_horiishichimeien_crawler.js',
            'test_ippodo_tea_crawler.js',
            'test_marukyu_koyamaen_crawler.js',
            'test_matcha_karu_crawler.js',
            'test_nakamura_tokichi_crawler.js',
            'test_poppatea_crawler.js',
            'test_sazentea_crawler.js',
            'test_sho_cha_crawler.js',
            'test_yoshien_crawler.js'
        ];
        
        this.results = {
            passed: [],
            failed: [],
            skipped: []
        };
    }
    
    async runTest(testFile) {
        return new Promise((resolve) => {
            console.log(`\n${'='.repeat(80)}`);
            console.log(`🧪 Running ${testFile}`);
            console.log(`${'='.repeat(80)}`);
            
            const testPath = path.join(__dirname, testFile);
            
            // Check if test file exists
            if (!fs.existsSync(testPath)) {
                console.log(`❌ Test file not found: ${testFile}`);
                this.results.skipped.push({
                    file: testFile,
                    reason: 'Test file not found'
                });
                resolve();
                return;
            }
            
            const startTime = Date.now();
            const nodeProcess = spawn('node', [testFile], {
                stdio: 'inherit',
                cwd: __dirname
            });
            
            nodeProcess.on('close', (code) => {
                const duration = Date.now() - startTime;
                const durationSeconds = (duration / 1000).toFixed(2);
                
                if (code === 0) {
                    console.log(`\n✅ ${testFile} PASSED (${durationSeconds}s)`);
                    this.results.passed.push({
                        file: testFile,
                        duration: durationSeconds
                    });
                } else {
                    console.log(`\n❌ ${testFile} FAILED (${durationSeconds}s)`);
                    this.results.failed.push({
                        file: testFile,
                        duration: durationSeconds,
                        exitCode: code
                    });
                }
                resolve();
            });
            
            nodeProcess.on('error', (error) => {
                console.error(`❌ Error running ${testFile}:`, error.message);
                this.results.failed.push({
                    file: testFile,
                    error: error.message
                });
                resolve();
            });
        });
    }
    
    async runAllTests() {
        console.log('🚀 Starting ZenRadar Crawler Test Suite');
        console.log(`📊 Running ${this.testFiles.length} crawler tests`);
        console.log(`⏰ Started at: ${new Date().toLocaleString()}\n`);
        
        const overallStartTime = Date.now();
        
        // Run tests sequentially to avoid overwhelming servers
        for (const testFile of this.testFiles) {
            await this.runTest(testFile);
            
            // Small delay between tests to be respectful to servers
            if (this.testFiles.indexOf(testFile) < this.testFiles.length - 1) {
                console.log('\n⏸️  Waiting 2 seconds before next test...');
                await new Promise(resolve => setTimeout(resolve, 2000));
            }
        }
        
        const overallDuration = ((Date.now() - overallStartTime) / 1000).toFixed(2);
        
        this.printSummary(overallDuration);
    }
    
    printSummary(overallDuration) {
        console.log('\n' + '='.repeat(80));
        console.log('📊 CRAWLER TEST SUITE SUMMARY');
        console.log('='.repeat(80));
        
        console.log(`⏰ Total execution time: ${overallDuration}s`);
        console.log(`📊 Total tests: ${this.testFiles.length}`);
        console.log(`✅ Passed: ${this.results.passed.length}`);
        console.log(`❌ Failed: ${this.results.failed.length}`);
        console.log(`⏭️  Skipped: ${this.results.skipped.length}`);
        
        if (this.results.passed.length > 0) {
            console.log('\n✅ PASSED TESTS:');
            this.results.passed.forEach(result => {
                console.log(`  • ${result.file} (${result.duration}s)`);
            });
        }
        
        if (this.results.failed.length > 0) {
            console.log('\n❌ FAILED TESTS:');
            this.results.failed.forEach(result => {
                console.log(`  • ${result.file} (${result.duration || 'unknown'}s) - Exit code: ${result.exitCode || result.error}`);
            });
        }
        
        if (this.results.skipped.length > 0) {
            console.log('\n⏭️  SKIPPED TESTS:');
            this.results.skipped.forEach(result => {
                console.log(`  • ${result.file} - ${result.reason}`);
            });
        }
        
        const overallSuccess = this.results.failed.length === 0;
        console.log('\n' + '='.repeat(80));
        
        if (overallSuccess) {
            console.log('🎉 ALL TESTS PASSED! ZenRadar crawlers are working properly.');
        } else {
            console.log('⚠️  Some tests failed. Please check the failed crawlers above.');
        }
        
        console.log('='.repeat(80));
        
        // Generate test report
        this.generateTestReport();
    }
    
    generateTestReport() {
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const reportFile = `test-report-${timestamp}.json`;
        
        const report = {
            timestamp: new Date().toISOString(),
            summary: {
                total: this.testFiles.length,
                passed: this.results.passed.length,
                failed: this.results.failed.length,
                skipped: this.results.skipped.length
            },
            results: this.results
        };
        
        try {
            fs.writeFileSync(reportFile, JSON.stringify(report, null, 2));
            console.log(`📄 Test report saved as: ${reportFile}`);
        } catch (error) {
            console.log(`⚠️  Could not save test report: ${error.message}`);
        }
    }
    
    async runSpecificTests(testNames) {
        console.log(`🧪 Running specific tests: ${testNames.join(', ')}`);
        
        const validTests = testNames.filter(name => {
            const fileName = name.startsWith('test_') ? name : `test_${name}_crawler.js`;
            return this.testFiles.includes(fileName);
        });
        
        if (validTests.length === 0) {
            console.log('❌ No valid test files found for the specified tests');
            console.log(`Available tests: ${this.testFiles.join(', ')}`);
            return;
        }
        
        const overallStartTime = Date.now();
        
        for (const testName of validTests) {
            const fileName = testName.startsWith('test_') ? testName : `test_${testName}_crawler.js`;
            await this.runTest(fileName);
        }
        
        const overallDuration = ((Date.now() - overallStartTime) / 1000).toFixed(2);
        this.printSummary(overallDuration);
    }
}

// Handle command line arguments
async function main() {
    const args = process.argv.slice(2);
    const runner = new CrawlerTestRunner();
    
    if (args.length === 0) {
        // Run all tests
        await runner.runAllTests();
    } else if (args[0] === '--list') {
        // List available tests
        console.log('📋 Available crawler tests:');
        runner.testFiles.forEach((file, index) => {
            const crawlerName = file.replace('test_', '').replace('_crawler.js', '');
            console.log(`  ${index + 1}. ${crawlerName}`);
        });
    } else if (args[0] === '--help' || args[0] === '-h') {
        // Show help
        console.log('ZenRadar Crawler Test Runner');
        console.log('\nUsage:');
        console.log('  node test_all_crawlers.js              # Run all tests');
        console.log('  node test_all_crawlers.js --list       # List available tests');
        console.log('  node test_all_crawlers.js yoshien      # Run specific crawler test');
        console.log('  node test_all_crawlers.js yoshien emeri # Run multiple specific tests');
        console.log('  node test_all_crawlers.js --help       # Show this help');
    } else {
        // Run specific tests
        await runner.runSpecificTests(args);
    }
}

// Run the main function
if (require.main === module) {
    main().catch(console.error);
}

module.exports = CrawlerTestRunner;
