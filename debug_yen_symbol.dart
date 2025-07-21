// ignore_for_file: avoid_print

void main() {
  print('=== Testing Yen Symbol Detection ===');

  final testPrices = ['¥3,000', '¥6,000', '¥4,000'];

  for (final price in testPrices) {
    print('Price: "$price"');
    print('Contains ¥: ${price.contains('¥')}');
    print('Contains \\u00A5: ${price.contains('\u00A5')}');
    print('Price bytes: ${price.codeUnits}');
    print('First char code: ${price.codeUnitAt(0)}');
    print('Is first char 165: ${price.codeUnitAt(0) == 165}');

    // Test different detection methods
    final hasYen1 = price.contains('¥');
    final hasYen2 = price.contains('\u00A5');
    final hasYen3 = price.codeUnitAt(0) == 165;
    final hasYen4 = price.startsWith('¥');

    print('Detection methods:');
    print('  method1 (¥): $hasYen1');
    print('  method2 (\\u00A5): $hasYen2');
    print('  method3 (code 165): $hasYen3');
    print('  method4 (startsWith): $hasYen4');
    print('');
  }
}
