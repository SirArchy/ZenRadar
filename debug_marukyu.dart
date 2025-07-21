// Debug script for Marukyu-Koyamaen crawling issues
// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

void main() async {
  print('🔍 Debugging Marukyu-Koyamaen crawling...');

  const url =
      'https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha?currency=USD';

  try {
    print('📡 Fetching URL: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );

    print('📊 Response status: ${response.statusCode}');
    print('📏 Response length: ${response.body.length} characters');

    if (response.statusCode == 200) {
      final document = parse(response.body);

      // Try different product selectors
      final selectors = [
        '.item',
        '.product-item',
        '.product',
        '.card',
        '.product-card',
        '.product-listing',
        '.list-item',
        'article',
        '.entry',
        '[data-product]',
        '.shop-item',
        '.catalog-item',
      ];

      print('\n🔍 Testing different product selectors:');
      for (String selector in selectors) {
        final elements = document.querySelectorAll(selector);
        print('  $selector: ${elements.length} elements found');

        if (elements.isNotEmpty && elements.length < 20) {
          // Show sample content for reasonable number of elements
          for (int i = 0; i < elements.length && i < 3; i++) {
            final text = elements[i].text.trim();
            final preview =
                text.length > 100 ? '${text.substring(0, 100)}...' : text;
            print('    Element $i preview: "$preview"');
          }
        }
      }

      // Look for any matcha-related content
      print('\n🍵 Searching for matcha-related content:');
      final matchaElements = document
          .querySelectorAll('*')
          .where((element) {
            final text = element.text.toLowerCase();
            return text.contains('matcha') && text.length < 200;
          })
          .take(5);

      for (var element in matchaElements) {
        print('  Found: "${element.text.trim()}"');
        print('  Tag: ${element.localName}, Classes: ${element.classes}');
      }

      // Check page title and basic structure
      print('\n📄 Page structure:');
      print('  Title: ${document.querySelector('title')?.text ?? 'No title'}');
      print('  Body classes: ${document.querySelector('body')?.classes ?? []}');

      // Look for common e-commerce patterns
      final commonSelectors = [
        'main',
        '.main-content',
        '.products',
        '.catalog',
        '.shop',
        '#products',
        '.product-list',
        '.grid',
      ];

      print('\n🛒 Common e-commerce selectors:');
      for (String selector in commonSelectors) {
        final element = document.querySelector(selector);
        if (element != null) {
          print('  $selector: Found (${element.children.length} children)');
        }
      }

      // Check if it's a dynamic/JS-heavy site
      final scripts = document.querySelectorAll('script');
      final hasReact = scripts.any(
        (s) => s.text.contains('React') || s.text.contains('react'),
      );
      final hasVue = scripts.any(
        (s) => s.text.contains('Vue') || s.text.contains('vue'),
      );
      final hasAngular = scripts.any(
        (s) => s.text.contains('Angular') || s.text.contains('angular'),
      );

      print('\n⚙️ JavaScript frameworks detected:');
      print('  React: $hasReact');
      print('  Vue: $hasVue');
      print('  Angular: $hasAngular');
      print('  Total scripts: ${scripts.length}');
    } else {
      print('❌ Failed to fetch page: ${response.statusCode}');
      print(
        'Response body preview: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}',
      );
    }
  } catch (e) {
    print('💥 Error: $e');
  }
}
