import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/sftp/host/host_cards.dart';
import 'package:luma/features/plugins/installed/sftp/host/this_device_page.dart';
import 'package:luma/theme/luma_theme.dart';

/// The "This device" screen makes one promise the Host tab does not: this
/// device is reachable while the screen is open, and not a moment longer.
/// These tests hold it to that with real loopback sockets — the same way
/// `sftp_host_test.dart` exercises the host itself. Nothing here leaves the
/// machine and no luma server is involved.

/// Lets the page's real socket work run. The tester's clock is fake, so each
/// step of the startup chain needs both the real event loop (for the I/O)
/// and a pump (to flush the continuation the fake zone is holding) — hence
/// the loop rather than one long wait.
Future<void> _breathe(WidgetTester tester, {int rounds = 10}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();
  }
}

/// The port the screen is telling the user to type, read off the screen
/// rather than out of the server, so the test fails if the two disagree.
int _portOnScreen(WidgetTester tester) {
  final row = tester.widget<HostCopyRow>(
    find.byWidgetPredicate((w) => w is HostCopyRow && w.label == 'Port'),
  );
  return int.parse(row.value);
}

Future<bool> _canConnect(WidgetTester tester, int port) async {
  var reachable = false;
  await tester.runAsync(() async {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      reachable = true;
    } on SocketException {
      reachable = false;
    }
  });
  return reachable;
}

Future<void> _pumpPage(WidgetTester tester, Directory directory) async {
  tester.view.physicalSize = const Size(1400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: LumaTheme.dark,
      home: SftpThisDevicePage(initialDirectory: directory),
    ),
  );
  await _breathe(tester);
}

void main() {
  late Directory shared;

  setUp(() async {
    shared = await Directory.systemTemp.createTemp('luma_this_device');
    await File('${shared.path}${Platform.pathSeparator}note.txt')
        .writeAsString('hello');
  });

  tearDown(() async {
    if (await shared.exists()) await shared.delete(recursive: true);
  });

  testWidgets('opening the screen makes this device reachable',
      (tester) async {
    await _pumpPage(tester, shared);

    expect(find.text('Other devices can reach this one'), findsOneWidget);
    expect(await _canConnect(tester, _portOnScreen(tester)), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await _breathe(tester);
  });

  testWidgets('closing it takes the listener down with it', (tester) async {
    await _pumpPage(tester, shared);
    final port = _portOnScreen(tester);
    expect(await _canConnect(tester, port), isTrue);

    // Disposing the page is what leaving the screen does.
    await tester.pumpWidget(const SizedBox.shrink());
    await _breathe(tester);

    expect(await _canConnect(tester, port), isFalse);
  });

  testWidgets('sending luma to the background closes it too, and coming '
      'back reopens it', (tester) async {
    await _pumpPage(tester, shared);
    expect(await _canConnect(tester, _portOnScreen(tester)), isTrue);

    final port = _portOnScreen(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _breathe(tester);

    expect(await _canConnect(tester, port), isFalse);
    expect(
      find.text('Paused while luma is in the background'),
      findsOneWidget,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _breathe(tester);

    // The port is read again: a restart takes the default port back if the
    // first attempt had to settle for whatever the OS handed out.
    expect(await _canConnect(tester, _portOnScreen(tester)), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await _breathe(tester);
  });

  testWidgets('the credentials fit a phone without overflowing',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: SftpThisDevicePage(initialDirectory: shared),
      ),
    );
    await _breathe(tester);

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await _breathe(tester);
  });

  testWidgets('the pairing password is masked until it is asked for',
      (tester) async {
    await _pumpPage(tester, shared);

    HostCopyRow passwordRow() => tester.widget<HostCopyRow>(
          find.byWidgetPredicate(
            (w) => w is HostCopyRow && w.label == 'Pairing password',
          ),
        );

    expect(passwordRow().value, '••••-••••-••••-••••-••••');

    await tester.tap(find.byTooltip('Show'));
    await tester.pump();

    expect(passwordRow().value, isNot('••••-••••-••••-••••-••••'));
    expect(passwordRow().value.length, greaterThanOrEqualTo(8));

    await tester.pumpWidget(const SizedBox.shrink());
    await _breathe(tester);
  });
}
