// ignore_for_file: avoid_print

import 'lib/models/matcha_product.dart';

void main() {
  testCategoryDetection();
}

void testCategoryDetection() {
  print('=== Testing Category Detection with German Terms ===\n');

  // Test cases with the new German terms
  final testCases = [
    // Accessories - German terms
    {'name': 'Chawan Schale', 'expected': 'Accessories'},
    {'name': 'Chasen Bambusbesen', 'expected': 'Accessories'},
    {'name': 'Matcha Halter', 'expected': 'Accessories'},
    {'name': 'Teetasse für Grüntee', 'expected': 'Accessories'},
    {'name': 'Japanische Teetassen', 'expected': 'Accessories'},
    {'name': 'Teebecher aus Keramik', 'expected': 'Accessories'},
    {'name': 'Tea Pot Premium', 'expected': 'Accessories'},
    {'name': 'Glas Teekanne', 'expected': 'Accessories'},
    {'name': 'Matcha Besen', 'expected': 'Accessories'},
    {'name': 'Geschenkgutschein 50€', 'expected': 'Accessories'},
    {'name': 'Gutschein für Tee', 'expected': 'Accessories'},
    {'name': 'Keramik Schale', 'expected': 'Accessories'},
    {'name': 'Tea Bowl', 'expected': 'Accessories'},
    {'name': 'Bamboo Spoon', 'expected': 'Accessories'},
    {'name': 'Matcha Löffel', 'expected': 'Accessories'},

    // Matcha products
    {'name': 'Bio Matcha Premium', 'expected': 'Matcha'},
    {'name': 'Ceremonial Matcha', 'expected': 'Matcha'},

    // Other tea types
    {'name': 'Genmaicha Superior', 'expected': 'Genmaicha'},
    {'name': 'Hojicha Roasted', 'expected': 'Hojicha'},
    {'name': 'Earl Grey Black Tea', 'expected': 'Black Tea'},

    // Tea sets
    {'name': 'Matcha Set Premium', 'expected': 'Tea Set'},
    {'name': 'Tea Kit Starter', 'expected': 'Tea Set'},
  ];

  int passed = 0;
  int failed = 0;

  for (final testCase in testCases) {
    final name = testCase['name'] as String;
    final expected = testCase['expected'] as String;

    final detected = MatchaProduct.detectCategory(name, 'Test Site');

    if (detected == expected) {
      print('✅ "$name" → $detected');
      passed++;
    } else {
      print('❌ "$name" → $detected (expected: $expected)');
      failed++;
    }
  }

  print('\n=== Results ===');
  print('Passed: $passed');
  print('Failed: $failed');
  print('Total: ${passed + failed}');

  if (failed == 0) {
    print('🎉 All tests passed! Category detection is working correctly.');
  } else {
    print('⚠️ Some tests failed. Review the detection logic.');
  }
}
