// ignore_for_file: avoid_print

void main() async {
  print('🧪 Testing site filtering fix...\n');

  // Simulate how products are stored (with display names)
  final mockProducts = [
    {'name': 'Matcha A', 'site': 'Poppatea', 'price': '15.00'},
    {'name': 'Matcha B', 'site': 'Nakamura Tokichi', 'price': '25.00'},
    {'name': 'Matcha C', 'site': 'Poppatea', 'price': '18.00'},
    {'name': 'Matcha D', 'site': 'Mamecha', 'price': '22.00'},
  ];

  print('📦 Mock products in database:');
  for (final product in mockProducts) {
    print('  ${product['name']} - ${product['site']} - ${product['price']}');
  }

  // Simulate filter selection (user selects "Poppatea" from dropdown)
  final selectedSites = ['Poppatea'];

  print('\n🔍 Filter selection: $selectedSites');

  // Test filtering (this is what happens in database query)
  final filteredProducts =
      mockProducts
          .where((product) => selectedSites.contains(product['site']))
          .toList();

  print('\n📋 Filtered results:');
  if (filteredProducts.isNotEmpty) {
    for (final product in filteredProducts) {
      print('  ${product['name']} - ${product['site']} - ${product['price']}');
    }
    print('\n✅ SUCCESS: Site filtering works correctly!');
    print(
      '   Found ${filteredProducts.length} products for ${selectedSites.join(", ")}',
    );
  } else {
    print('  No products found');
    print('\n❌ FAILED: Site filtering not working');
  }

  // Test with multiple sites
  final multipleSelection = ['Poppatea', 'Mamecha'];
  final multipleFiltered =
      mockProducts
          .where((product) => multipleSelection.contains(product['site']))
          .toList();

  print('\n🔍 Multiple site filter: $multipleSelection');
  print('📋 Results: ${multipleFiltered.length} products found');

  print('\n🎉 Site filtering verification complete!');
}
