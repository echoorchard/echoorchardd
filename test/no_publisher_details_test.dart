import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Developer and company contact details belong only on the Play listing and
/// the website privacy policy, never inside the app. This guards lib/ and
/// assets/ against them creeping back in.
void main() {
  const banned = [
    'comfort',
    'bukunmi',
    'bello',
    'faithia',
    'mummy',
    'business venture',
    'echoorfaigames',
    'echobelogame',
    '.com.ng',
    'ilesha',
    'osun',
    'nigeria',
  ];

  test('no developer, company, email, website or address in lib/ or assets/', () {
    final hits = <String>[];
    for (final dir in ['lib', 'assets']) {
      for (final entity in Directory(dir).listSync(recursive: true)) {
        if (entity is! File) continue;
        // The font licence text is third-party and names its own authors.
        if (entity.path.endsWith('OFL.txt')) continue;
        final text = String.fromCharCodes(entity.readAsBytesSync()).toLowerCase();
        for (final word in banned) {
          if (text.contains(word)) hits.add('${entity.path}: "$word"');
        }
      }
    }
    expect(hits, isEmpty);
  });

  test('the credits screen and its route are gone', () {
    expect(File('lib/screens/credits_screen.dart').existsSync(), isFalse);
    expect(File('lib/publisher.dart').existsSync(), isFalse);
    expect(File('lib/routing/app_routes.dart').readAsStringSync(), isNot(contains('credits')));
  });
}
