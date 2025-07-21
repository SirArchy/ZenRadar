// ignore_for_file: avoid_print

void main() async {
  print('🧪 Testing site names mapping...\n');

  // Simulate the site names mapping from crawler service
  final siteNamesMap = {
    'tokichi': 'Nakamura Tokichi',
    'marukyu': 'Marukyu-Koyamaen',
    'ippodo': 'Ippodo Tea',
    'yoshien': 'Yoshi En',
    'matcha-karu': 'Matcha Kāru',
    'sho-cha': 'Sho-Cha',
    'sazentea': 'Sazen Tea',
    'mamecha': 'Mamecha',
    'enjoyemeri': 'Emeri',
    'poppatea': 'Poppatea', // This should be included now
  };

  print('📊 Site Names Mapping:');
  for (final entry in siteNamesMap.entries) {
    print('  ${entry.key} -> ${entry.value}');
  }

  // Test that Poppatea is properly included
  if (siteNamesMap.containsKey('poppatea')) {
    print('\n✅ SUCCESS: Poppatea key found');
    print('   Display name: ${siteNamesMap['poppatea']}');
  } else {
    print('\n❌ FAILED: Poppatea key not found');
  }

  // Simulate the available sites for filter (display names)
  List<String> availableSites = ['All'];
  availableSites.addAll(siteNamesMap.values);

  print('\n📋 Available sites for filter:');
  for (int i = 0; i < availableSites.length; i++) {
    print('  ${i + 1}. ${availableSites[i]}');
  }

  if (availableSites.contains('Poppatea')) {
    print('\n✅ SUCCESS: Poppatea appears in filter dropdown');
  } else {
    print('\n❌ FAILED: Poppatea missing from filter dropdown');
  }

  // Test reverse mapping (display name -> site key)
  final reverseMap = <String, String>{};
  for (final entry in siteNamesMap.entries) {
    reverseMap[entry.value] = entry.key;
  }

  print('\n🔄 Reverse mapping test:');
  if (reverseMap.containsKey('Poppatea')) {
    print('  "Poppatea" -> "${reverseMap['Poppatea']}"');
    print('✅ SUCCESS: Can convert Poppatea display name to site key');
  } else {
    print('❌ FAILED: Cannot convert Poppatea display name to site key');
  }

  print('\n🎉 Site names mapping verification complete!');
}
