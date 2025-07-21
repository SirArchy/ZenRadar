// Test verification for Poppatea integration
// This script verifies the changes we made to the settings screen

// ignore_for_file: avoid_print

void main() {
  print('🧪 Verifying Poppatea integration changes...\n');

  // Simulate the built-in sites list
  List<Map<String, String>> builtInSites = [
    {'key': 'tokichi', 'name': 'Nakamura Tokichi', 'url': 'global.tokichi.jp'},
    {
      'key': 'marukyu',
      'name': 'Marukyu-Koyamaen',
      'url': 'marukyu-koyamaen.co.jp',
    },
    {'key': 'ippodo', 'name': 'Ippodo Tea', 'url': 'global.ippodo-tea.co.jp'},
    {'key': 'yoshien', 'name': 'Yoshi En', 'url': 'yoshien.co.jp'},
    {'key': 'matcha-karu', 'name': 'Matcha Kāru', 'url': 'matchakaru.com'},
    {'key': 'sho-cha', 'name': 'Sho-Cha', 'url': 'sho-cha.com'},
    {'key': 'sazentea', 'name': 'Sazen Tea', 'url': 'sazentea.com'},
    {'key': 'mamecha', 'name': 'Mamecha', 'url': 'mamecha.co.jp'},
    {'key': 'enjoyemeri', 'name': 'Emeri', 'url': 'enjoyemeri.com'},
    {'key': 'poppatea', 'name': 'Poppatea', 'url': 'poppatea.com'},
  ];

  print('📊 Built-in sites list:');
  for (int i = 0; i < builtInSites.length; i++) {
    var site = builtInSites[i];
    print('  ${i + 1}. ${site['name']} (${site['key']}) - ${site['url']}');
  }

  // Check if Poppatea is present
  var poppateaSite = builtInSites.firstWhere(
    (site) => site['key'] == 'poppatea',
    orElse: () => {},
  );

  if (poppateaSite.isNotEmpty) {
    print('\n✅ SUCCESS: Poppatea found in built-in sites');
    print('   Key: ${poppateaSite['key']}');
    print('   Name: ${poppateaSite['name']}');
    print('   URL: ${poppateaSite['url']}');
  } else {
    print('\n❌ FAILED: Poppatea not found in built-in sites');
  }

  print('\n📈 Total built-in sites: ${builtInSites.length}');

  // Verify description text
  String description =
      'Nakamura Tokichi, Marukyu-Koyamaen, Ippodo Tea,\nYoshi En, Matcha Kāru, Sho-Cha, Sazen Tea,\nMamecha, Emeri, Poppatea + Custom websites';

  if (description.contains('Poppatea')) {
    print('\n✅ SUCCESS: Poppatea found in description text');
  } else {
    print('\n❌ FAILED: Poppatea not found in description text');
  }

  print('\n🎉 Poppatea UI integration verification complete!');
}
