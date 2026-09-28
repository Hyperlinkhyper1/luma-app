import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dutch catalog covers every English message and placeholder', () {
    Map<String, dynamic> read(String locale) =>
        jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
            as Map<String, dynamic>;

    final english = read('en');
    final dutch = read('nl');
    final keys = english.keys.where((key) => !key.startsWith('@')).toSet();
    final dutchKeys = dutch.keys.where((key) => !key.startsWith('@')).toSet();
    expect(dutchKeys.difference(keys), isEmpty, reason: 'Orphaned Dutch keys');
    expect(keys.difference(dutchKeys), isEmpty, reason: 'Missing Dutch keys');

    final placeholder = RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)(?=[},])');
    for (final key in keys) {
      final source = (english[key] as String);
      final translation = (dutch[key] as String);
      final sourceNames = placeholder
          .allMatches(source)
          .map((match) => match.group(1))
          .toSet();
      final translatedNames = placeholder
          .allMatches(translation)
          .map((match) => match.group(1))
          .toSet();
      expect(translatedNames, sourceNames, reason: 'Placeholders in $key');
    }
  });
}
