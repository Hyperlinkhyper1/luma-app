import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/account/account_page.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/storage/storage_guard_scope.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  group('StorageGuardService category aggregation', () {
    final separator = Platform.pathSeparator;
    final root = separator == r'\' ? r'C:\luma-support' : '/luma-support';
    String path(String relative) => '$root$separator$relative';

    test('sorts categories largest first and groups root files as app data', () {
      final categories = StorageGuardService.aggregateCategories(
        rootPath: root,
        entries: [
          StorageFileEntry(path: path('notes.json'), bytes: 20),
          StorageFileEntry(path: path('finance/db.sqlite'), bytes: 500),
          StorageFileEntry(path: path('finance/exports.json'), bytes: 200),
          StorageFileEntry(path: path('plugins/catalog.json'), bytes: 300),
        ],
      );

      expect(categories, [
        const StorageCategory(name: 'Finance', bytes: 700),
        const StorageCategory(name: 'Plugins', bytes: 300),
        const StorageCategory(name: 'App data', bytes: 20),
      ]);
    });

    test('excludes ignored directories and log files from the breakdown', () {
      final categories = StorageGuardService.aggregateCategories(
        rootPath: root,
        entries: [
          StorageFileEntry(path: path('notes.json'), bytes: 20),
          StorageFileEntry(path: path('tools/ffmpeg.exe'), bytes: 500),
          StorageFileEntry(path: path('gallery_cache/thumb.jpg'), bytes: 500),
          StorageFileEntry(path: path('luma_shared/archive.zip'), bytes: 500),
          StorageFileEntry(path: path('debug.LOG'), bytes: 500),
        ],
      );

      expect(categories, [
        const StorageCategory(name: 'App data', bytes: 20),
      ]);
    });
  });

  testWidgets('the local storage card expands to its empty state',
      (tester) async {
    tester.view.physicalSize = const Size(320, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final guard = StorageGuardService();
    addTearDown(guard.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(
          body: StorageGuardScope(
            service: guard,
            child: const LocalStorageCard(),
          ),
        ),
      ),
    );

    expect(find.text("What's using space?"), findsNothing);
    await tester.tap(find.byKey(const ValueKey('local-storage-card')));
    await tester.pumpAndSettle();

    expect(find.text("What's using space?"), findsOneWidget);
    expect(find.text('No counted data yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a populated breakdown stays readable on a narrow card',
      (tester) async {
    tester.view.physicalSize = const Size(280, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final guard = _TestStorageGuard(
      used: 3 * 1024 * 1024,
      limit: 30 * 1024 * 1024,
      categories: const [
        StorageCategory(
          name: 'A very long plugin category name that should ellipsize',
          bytes: 2 * 1024 * 1024,
        ),
        StorageCategory(name: 'Notes', bytes: 1024),
      ],
    );
    addTearDown(guard.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(
          body: StorageGuardScope(
            service: guard,
            child: const LocalStorageCard(),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('local-storage-card')));
    await tester.pumpAndSettle();

    expect(find.text("What's using space?"), findsOneWidget);
    expect(find.text('2.0 MB'), findsOneWidget);
    final categoryText = tester.widget<Text>(find.text(
      'A very long plugin category name that should ellipsize',
    ));
    expect(categoryText.maxLines, 1);
    expect(categoryText.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });
}

class _TestStorageGuard extends StorageGuardService {
  _TestStorageGuard({
    required this.used,
    required this.limit,
    required this.categories,
  });

  final int used;
  final int limit;
  final List<StorageCategory> categories;

  @override
  int get usedBytes => used;

  @override
  int get limitBytes => limit;

  @override
  List<StorageCategory> get breakdown => categories;
}
