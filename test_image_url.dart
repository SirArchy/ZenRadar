// ignore_for_file: avoid_print

// ignore: library_prefixes
import 'test_url_processing.dart' as ImageUrlProcessor;

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
