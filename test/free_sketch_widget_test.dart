import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/free_sketch/free_sketch_page.dart';
import 'package:luma/features/plugins/installed/free_sketch/free_sketch_repository.dart';
import 'package:luma/features/plugins/installed/free_sketch/free_sketch_scope.dart';
import 'package:luma/features/plugins/installed/free_sketch/model/sketch_tool.dart';
import 'package:luma/features/plugins/installed/free_sketch/ui/sketch_canvas.dart';
import 'package:luma/features/plugins/installed/free_sketch/ui/sketch_studio.dart';
import 'package:luma/features/plugins/installed/free_sketch/ui/studio_controller.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/theme/luma_theme.dart';

/// The studio end to end: create an artwork from the gallery, paint on it
/// with a finger, undo, switch tools from the keyboard, and come back to the
/// gallery with the artwork saved.
///
/// Opening a document reads files and generates brush textures in an
/// isolate, and saving encodes PNGs on the engine — none of which completes
/// in the fake-async zone. `settle` pumps first and then hands out slices of
/// real time, in that order.
void main() {
  late Directory root;
  late FreeSketchRepository repository;
  late StorageGuardService storage;

  setUp(() {
    storage = _QuietStorageGuard();
    StorageGuardService.instance = storage;
  });

  Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> settleUntil(WidgetTester tester, bool Function() done, {int max = 60}) async {
    for (var i = 0; i < max && !done(); i++) {
      await settle(tester, rounds: 1);
    }
    expect(done(), isTrue, reason: 'timed out waiting');
  }

  testWidgets('create, paint, undo, switch tools, and save back to the gallery', (tester) async {
    root = (await tester.runAsync(() => Directory.systemTemp.createTemp('free_sketch_widget')))!;
    repository = FreeSketchRepository(root: () async => root);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(
          body: FreeSketchScope(repository: repository, child: const FreeSketchPage()),
        ),
      ),
    );
    await settleUntil(tester, () => find.text('Your gallery is empty').evaluate().isNotEmpty);

    await tester.tap(find.text('New artwork').first);
    await settle(tester);
    expect(find.text('Create'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Harbour study');
    await tester.tap(find.text('Square'));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await settleUntil(tester, () => find.byType(SketchCanvas).evaluate().isNotEmpty);

    final controller = tester.widget<SketchStudio>(find.byType(SketchStudio)).controller;
    expect(controller.title, 'Harbour study');
    expect((controller.width, controller.height), (2048, 2048));
    expect(controller.state.active.image, isNull);

    // One finger draws.
    final canvas = tester.getRect(find.byType(SketchCanvas));
    final start = canvas.center - const Offset(120, 0);
    final gesture = await tester.startGesture(start);
    for (var i = 1; i <= 12; i++) {
      await gesture.moveTo(start + Offset(i * 20.0, (i % 3) * 8.0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
    expect(controller.state.active.image, isNotNull, reason: 'the stroke landed on the layer');
    expect(controller.document.undoLabel, controller.brush.name);

    await tester.tap(find.byIcon(Icons.undo_rounded));
    await tester.pump();
    expect(controller.state.active.image, isNull);
    await tester.tap(find.byIcon(Icons.redo_rounded));
    await tester.pump();
    expect(controller.state.active.image, isNotNull);

    // Keyboard tool switching and brush sizing.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    expect(controller.tool, SketchTool.eraser);
    final size = controller.brush.size;
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
    await tester.pump();
    expect(controller.brush.size, greaterThan(size));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    expect(controller.tool, SketchTool.brush);

    // A new layer, then back to the gallery, which saves.
    controller.addLayer();
    await tester.pump();
    expect(controller.state.layers, hasLength(2));
    await tester.tap(find.byTooltip('Back to gallery'));
    await settleUntil(tester, () => find.byType(SketchStudio).evaluate().isEmpty);
    await settleUntil(tester, () => find.text('Harbour study').evaluate().isNotEmpty);

    final saved = (await tester.runAsync(() => repository.list()))!;
    expect(saved.single.meta.layers, hasLength(2));
    expect(saved.single.meta.layers.first.file, isNotNull, reason: 'the painted layer was written');
    expect(saved.single.thumbnail, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    storage.dispose();
    await tester.runAsync(() => _cleanUp(root));
  });

  testWidgets('the brush panel opens from the tool rail and switches brushes', (tester) async {
    root = (await tester.runAsync(() => Directory.systemTemp.createTemp('free_sketch_widget')))!;
    repository = FreeSketchRepository(root: () async => root);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final meta = (await tester.runAsync(() => repository.create(title: 'Panel', width: 512, height: 512)))!;
    final controller = (await tester.runAsync(() => StudioController.open(repository, meta.id)))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(
          body: SketchStudio(controller: controller, onClose: () async {}),
        ),
      ),
    );
    await settle(tester);

    // Tapping the active brush tool again opens its library.
    await tester.tap(find.byIcon(SketchTool.brush.icon).first);
    await tester.pump();
    expect(find.text('Brushes'), findsOneWidget);
    await tester.tap(find.text('Inking'));
    await tester.pump();
    await tester.tap(find.text('Brush pen'));
    await tester.pump();
    expect(controller.brush.id, 'brush_pen');

    await tester.tap(find.text('Settings'));
    await tester.pump();
    expect(find.text('Taper end'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await controller.close();
      controller.dispose();
    });
    await tester.pump(const Duration(seconds: 5));
    storage.dispose();
    await tester.runAsync(() => _cleanUp(root));
  });
}

/// Repository writes ask the storage guard to rescan the app folder three
/// seconds later. There is no app folder here, and a real timer armed inside
/// `runAsync` fights the fake clock, so the rescan is simply skipped.
class _QuietStorageGuard extends StorageGuardService {
  @override
  void scheduleRefresh() {}
}

/// Best effort: on Windows a write the fake clock never let finish can still
/// hold a handle in the folder.
Future<void> _cleanUp(Directory dir) async {
  try {
    await dir.delete(recursive: true);
  } on FileSystemException {
    // Left for the OS to clear out of the temp folder.
  }
}
