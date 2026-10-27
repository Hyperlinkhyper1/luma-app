import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/tests/benchmark_webview.dart';

void main() {
  const meta =
      '<meta charset="utf-8">'
      '<meta http-equiv="Content-Security-Policy" content="$sceneCsp">';

  group('withSceneCsp', () {
    test('goes right after the doctype so the page stays in standards mode',
        () {
      expect(
        withSceneCsp('<!DOCTYPE html>\n<html><head></head></html>'),
        '<!DOCTYPE html>$meta\n<html><head></head></html>',
      );
    });

    test('goes first when there is no doctype, dropping a BOM', () {
      expect(withSceneCsp('﻿<html></html>'), '$meta<html></html>');
    });

    test('leaves nothing to send data back with', () {
      expect(sceneCsp, contains("default-src 'none'"));
      expect(sceneCsp, contains('connect-src data: blob:;'));
      expect(sceneCsp, contains("form-action 'none'"));
      expect(sceneCsp, isNot(contains('file:')));
    });
  });

  test('sandboxedScene writes the copy once and reuses it', () async {
    final directory = Directory.systemTemp.createTempSync('luma_scene_csp');
    addTearDown(() => directory.deleteSync(recursive: true));
    final scene = File('${directory.path}/scene.html')
      ..writeAsStringSync('<!doctype html><p>é</p>');

    final copy = await sandboxedScene(scene.path);
    expect(copy, '${scene.path}.sandboxed.html');
    expect(File(copy).readAsStringSync(), '<!doctype html>$meta<p>é</p>');

    final written = File(copy).lastModifiedSync();
    expect(await sandboxedScene(scene.path), copy);
    expect(File(copy).lastModifiedSync(), written);
    expect(directory.listSync(), hasLength(2));
  });
}
