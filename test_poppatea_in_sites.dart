// ignore_for_file: avoid_print

import 'lib/services/crawler_service.dart';

void main() async {
  print('🧪 Testing Poppatea in site names map...\n');

  try {
    final crawler = CrawlerService();
    final siteNamesMap = crawler.getSiteNamesMap();

    print('📊 Available sites in crawler:');
    siteNamesMap.forEach((key, name) {
      print('  $key -> $name');
    });

    if (siteNamesMap.containsKey('poppatea')) {
      print('\n✅ SUCCESS: Poppatea found in site names map');
      print('   Key: poppatea');
      print('   Name: ${siteNamesMap['poppatea']}');
    } else {
      print('\n❌ FAILED: Poppatea not found in site names map');
    }

    print('\n📈 Total sites available: ${siteNamesMap.length}');
  } catch (e) {
    print('💥 Error: $e');
  }
}
