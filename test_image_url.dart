// ignore_for_file: avoid_print

import 'lib/services/image_url_processor.dart';

void main() {
  // Test URLs from your examples
  final testUrls = [
    'https://storage.googleapis.com/zenradar-acb85.firebasestorage.app/product-images/yoshien/yoshien_matchalffelflachshiro.jpg',
    'https://storage.googleapis.com/zenradar-acb85.firebasestorage.app/product-images/enjoyemeri/emeri_ceramic-matcha-bowl_ceramicmatchabowlchawan.jpg',
    'https://storage.googleapis.com/zenradar-acb85.firebasestorage.app/product-images/horiishichimeien/horiishichimeien_381381863819888638391382638380383100g_hojichapowder.jpg',
  ];

  print('🧪 Testing Image URL Processor on Web...\n');

  for (final url in testUrls) {
    print('Original: $url');
    final processed = ImageUrlProcessor.processImageUrl(url);
    print('Processed: $processed');
    print('---');
  }
}
