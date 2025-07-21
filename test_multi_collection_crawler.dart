// Test script to demonstrate the enhanced multi-collection crawler functionality
// This shows how the crawler now captures products from multiple categories instead of just matcha

// ignore_for_file: avoid_print

void main() async {
  print('🌟 ZenRadar Enhanced Multi-Collection Crawler Test');
  print('==================================================');

  // Simulate the enhanced crawler functionality
  print('\n📋 Sites with Enhanced Collection Coverage:');

  final enhancedSites = {
    'Nakamura Tokichi': [
      'Matcha Collection',
      'Genmaicha Collection',
      'Hojicha Collection',
      'Sencha Collection',
      'Gyokuro Collection',
      'Green Tea Collection',
      'Teaware Collection',
    ],
    'Marukyu-Koyamaen': [
      'Matcha Collection',
      'Sencha Collection',
      'Gyokuro Collection',
      'Genmaicha Collection',
      'Hojicha Collection',
    ],
    'Ippodo Tea': [
      'All Products Collection', // Comprehensive collection
    ],
    'Matcha Kāru': [
      'Matcha Tea Collection',
      'Tea Ceremony Collection',
      'Accessories Collection',
      'Gift Sets Collection',
    ],
    'Sazen Tea': [
      'Matcha Collection',
      'Sencha Collection',
      'Gyokuro Collection',
      'Hojicha Collection',
      'Tea Accessories Collection',
      'Teapots & Teacups Collection',
    ],
    'Poppatea': [
      'All Teas Collection', // Already comprehensive
    ],
    'Emeri': [
      'Shop All Collection', // Already comprehensive
    ],
  };

  for (var site in enhancedSites.entries) {
    print('\n🏪 ${site.key}:');
    for (var collection in site.value) {
      print('   📦 $collection');
    }
  }

  print('\n🎯 Expected Benefits:');
  print(
    '✅ Capture all tea categories (Matcha, Sencha, Gyokuro, Hojicha, Genmaicha)',
  );
  print('✅ Include tea accessories and teaware');
  print(
    '✅ Detect product categories automatically using MatchaProduct.detectCategory()',
  );
  print('✅ Enable comprehensive filtering by category in the app');
  print('✅ Prevent duplicate products across collections');
  print('✅ Respect websites with small delays between requests');

  print('\n📊 Category Detection Examples:');
  final testProducts = [
    'Ceremonial Matcha Powder',
    'Premium Sencha Green Tea',
    'Gyokuro First Flush',
    'Hojicha Roasted Tea',
    'Genmaicha Brown Rice Tea',
    'Bamboo Tea Whisk (Chasen)',
    'Ceramic Tea Bowl (Chawan)',
    'Tea Gift Set',
    'Earl Grey Black Tea',
  ];

  for (var product in testProducts) {
    var category = detectCategoryExample(product);
    print('   "$product" → Category: $category');
  }

  print('\n🚀 Ready to crawl comprehensive tea collections!');
}

// Example of category detection logic (simplified version)
String detectCategoryExample(String productName) {
  final lower = productName.toLowerCase();

  if (lower.contains('whisk') ||
      lower.contains('bowl') ||
      lower.contains('chawan') ||
      lower.contains('chasen')) {
    return 'Accessories';
  }
  if (lower.contains('set') || lower.contains('kit')) {
    return 'Tea Set';
  }
  if (lower.contains('genmaicha')) {
    return 'Genmaicha';
  }
  if (lower.contains('hojicha')) {
    return 'Hojicha';
  }
  if (lower.contains('sencha')) {
    return 'Sencha';
  }
  if (lower.contains('gyokuro')) {
    return 'Gyokuro';
  }
  if (lower.contains('black tea') || lower.contains('earl grey')) {
    return 'Black Tea';
  }
  if (lower.contains('matcha')) {
    return 'Matcha';
  }

  return 'Tea';
}
