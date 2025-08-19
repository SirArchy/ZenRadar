import 'dart:io';

void main() {
  final file = File('lib/services/firestore_service.dart');
  final content = file.readAsStringSync();

  // Replace all _firestore. with firestore. but keep the field declaration and getter
  final lines = content.split('\n');
  final fixedLines = <String>[];

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Skip the field declaration line and lines in the getter
    if (line.contains('FirebaseFirestore? _firestore;') ||
        line.contains('if (_firestore == null)') ||
        line.contains('return _firestore!;') ||
        line.contains('_firestore = FirebaseFirestore.instance;')) {
      fixedLines.add(line);
    } else {
      // Replace _firestore. with firestore. in all other cases
      fixedLines.add(line.replaceAll('_firestore.', 'firestore.'));
    }
  }

  file.writeAsStringSync(fixedLines.join('\n'));
  print('Fixed firestore_service.dart');
}
