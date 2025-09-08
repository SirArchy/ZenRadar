void main() {
  // Test the URL processing logic
  String testUrl =
      'https://storage.googleapis.com/zenradar-acb85.firebasestorage.app.firebasestorage.app/product-images/marukyu/marukyu_11a1040c1_aoarashi.jpg';

  print('Original URL: $testUrl');

  String processedUrl = processImageUrl(testUrl);

  print('Processed URL: $processedUrl');
  print('Fixed: ${testUrl != processedUrl}');
}

String processImageUrl(String url) {
  // Replace common placeholder patterns in image URLs
  String processedUrl = url;

  // Replace {width} patterns with a reasonable default width
  processedUrl = processedUrl.replaceAll('{width}', '400');
  processedUrl = processedUrl.replaceAll('%7Bwidth%7D', '400');

  // Replace {height} patterns with a reasonable default height
  processedUrl = processedUrl.replaceAll('{height}', '400');
  processedUrl = processedUrl.replaceAll('%7Bheight%7D', '400');

  // Fix doubled Firebase Storage domains (e.g., firebasestorage.app.firebasestorage.app)
  // This must be first to handle URLs that already have the doubled domain
  if (processedUrl.contains('.firebasestorage.app.firebasestorage.app')) {
    processedUrl = processedUrl.replaceAll(
      '.firebasestorage.app.firebasestorage.app',
      '.firebasestorage.app',
    );
    print('🔧 Fixed doubled Firebase Storage domain: $url -> $processedUrl');
  }
  // Ensure Firebase Storage URLs use the correct format
  // Only process if it wasn't already fixed above
  else if (processedUrl.contains('storage.googleapis.com')) {
    // Fix potential missing .firebasestorage.app in Firebase Storage URLs
    final regex = RegExp(
      r'storage\.googleapis\.com/([^/\.]+)(?!/[^/]*\.firebasestorage\.app)',
    );
    final newUrl = processedUrl.replaceAllMapped(regex, (match) {
      final bucketName = match.group(1);
      if (bucketName != null && !bucketName.contains('.firebasestorage.app')) {
        return 'storage.googleapis.com/$bucketName.firebasestorage.app';
      }
      return match.group(0)!;
    });

    if (newUrl != processedUrl) {
      print('🔧 Added .firebasestorage.app suffix: $processedUrl -> $newUrl');
      processedUrl = newUrl;
    }
  }

  return processedUrl;
}
