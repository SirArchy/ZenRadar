// ignore_for_file: avoid_print

import 'lib/models/matcha_product.dart';

void main() {
  // Test the filter chip logic
  print('Testing ProductFilter copyWith method...');

  // Create a filter with inStock set to true
  var filter = ProductFilter(inStock: true, favoritesOnly: false);
  print(
    'Initial filter - inStock: ${filter.inStock}, favoritesOnly: ${filter.favoritesOnly}',
  );

  // Test the "All" chip logic - should clear inStock
  var allFilter = filter.copyWith(clearInStock: true, favoritesOnly: false);
  print(
    'After "All" chip - inStock: ${allFilter.inStock}, favoritesOnly: ${allFilter.favoritesOnly}',
  );

  // Test the "In Stock" chip logic - should set inStock to true when selected
  var inStockFilter = ProductFilter().copyWith(
    inStock: true,
    favoritesOnly: false,
  );
  print(
    'After "In Stock" chip selected - inStock: ${inStockFilter.inStock}, favoritesOnly: ${inStockFilter.favoritesOnly}',
  );

  // Test the "In Stock" chip logic - should clear inStock when deselected
  var inStockDeselected = inStockFilter.copyWith(clearInStock: true);
  print(
    'After "In Stock" chip deselected - inStock: ${inStockDeselected.inStock}, favoritesOnly: ${inStockDeselected.favoritesOnly}',
  );

  print('Filter test completed successfully!');
}
