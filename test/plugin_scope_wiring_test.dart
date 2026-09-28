import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every plugin scope used by a page is registered at the app root', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final pluginDirectory = Directory('lib/features/plugins/installed');
    final scopeUse = RegExp(r'\b(\w+Scope)\.of\(context\)');
    final missing = <String>{};

    for (final entity in pluginDirectory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in scopeUse.allMatches(source)) {
        final name = match.group(1)!;
        if (!mainSource.contains('$name(')) missing.add(name);
      }
    }

    expect(
      missing.isEmpty,
      true,
      reason: 'Missing root scopes: ${missing.join(', ')}',
    );
  });
}
