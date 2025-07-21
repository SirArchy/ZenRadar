// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  await debugMamechaPrices();
}

Future<void> debugMamechaPrices() async {
  print('=== Debugging Mamecha Price Structure ===');

  try {
    final response = await http.get(
      Uri.parse('https://www.mamecha.com/online-shopping-1/'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      },
    );

    if (response.statusCode != 200) {
      print('Failed to fetch page: ${response.statusCode}');
      return;
    }

    final document = html_parser.parse(response.body);

    // Look at the first matcha product in detail
    final productContainers = document.querySelectorAll('[id*="cc-m-product"]');

    for (int i = 0; i < Math.min(3, productContainers.length); i++) {
      final container = productContainers[i];
      final nameElement = container.querySelector('h4');
      final name = nameElement?.text.trim() ?? '';

      if (name.toLowerCase().contains('matcha') ||
          name.toLowerCase().contains('sencha')) {
        print('\n=== Product: "$name" ===');
        print('Container ID: ${container.id}');

        // Look at all elements that might contain prices
        final allElements = container.querySelectorAll('*');
        print('Total child elements: ${allElements.length}');

        for (int j = 0; j < allElements.length; j++) {
          final element = allElements[j];
          final text = element.text.trim();

          if (text.contains('€') && text.length < 50) {
            print(
              'Element ${j + 1} (${element.localName}.${element.classes.join('.')}): "$text"',
            );
            print(
              '  Parent: ${element.parent?.localName}.${element.parent?.classes.join('.') ?? ''}',
            );
            print('  Attributes: ${element.attributes}');
          }
        }

        // Also check the raw HTML structure
        print('\n--- Raw HTML Sample ---');
        final htmlSample =
            container.outerHtml.length > 1000
                ? '${container.outerHtml.substring(0, 1000)}...'
                : container.outerHtml;
        print(htmlSample);

        break; // Just analyze the first matcha product
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}

class Math {
  static int min(int a, int b) => a < b ? a : b;
}
