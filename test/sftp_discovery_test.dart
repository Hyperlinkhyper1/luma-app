import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/widgets.dart';
import 'package:luma/features/plugins/installed/sftp/host/host_discovery.dart';
import 'package:luma/features/plugins/installed/sftp/host/host_protocol.dart';
import 'package:luma/features/plugins/installed/sftp/sftp_dialogs.dart';
import 'package:luma/features/plugins/installed/sftp/sftp_site_manager.dart';
import 'package:luma/theme/luma_theme.dart';
import 'package:nsd/nsd.dart';

/// Covers finding luma hosts on the local network: reading the mDNS record,
/// the "On this network" list, and the quick-connect dialog that still asks
/// for the pairing password and lets the port be changed.
void main() {
  Map<String, Uint8List?> txt(String name, int version) => {
        'n': Uint8List.fromList(utf8.encode(name)),
        'v': Uint8List.fromList(utf8.encode('$version')),
      };

  group('reading a host record', () {
    test('prefers a routable IPv4 address over the host name', () {
      final host = DiscoveredHost.fromService(
        Service(
          name: 'Stephan-PC-ab12',
          type: kLumaHostServiceType,
          host: 'Stephan-PC.local.',
          port: 7420,
          txt: txt('Stephan-PC', kHostProtocolVersion),
          addresses: [
            InternetAddress('169.254.3.4'),
            InternetAddress('192.168.2.10'),
          ],
        ),
      );

      expect(host, isNotNull);
      expect(host!.address, '192.168.2.10');
      expect(host.port, 7420);
      expect(host.deviceName, 'Stephan-PC');
      expect(host.compatible, isTrue);
    });

    test('falls back to the host name without its trailing dot', () {
      final host = DiscoveredHost.fromService(
        Service(
          name: 'laptop-zz99',
          host: 'laptop.local.',
          port: 51234,
          txt: txt('laptop', kHostProtocolVersion),
        ),
      );
      expect(host!.address, 'laptop.local');
      expect(host.port, 51234);
    });

    test('flags a host running another protocol version', () {
      final host = DiscoveredHost.fromService(
        Service(
          name: 'old-aaaa',
          port: 7420,
          addresses: [InternetAddress('192.168.2.20')],
          txt: txt('old', kHostProtocolVersion - 1),
        ),
      );
      expect(host!.compatible, isFalse);
    });

    test('ignores a record that has not resolved yet', () {
      expect(
        DiscoveredHost.fromService(const Service(name: 'x', port: 7420)),
        isNull,
      );
      expect(
        DiscoveredHost.fromService(
          Service(name: 'x', addresses: [InternetAddress('192.168.2.5')]),
        ),
        isNull,
      );
    });
  });

  Widget wrap(Widget child) => MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(body: child),
      );

  const nearby = DiscoveredHost(
    id: 'Stephan-PC-ab12',
    deviceName: 'Stephan-PC',
    address: '192.168.2.10',
    port: 7420,
    version: kHostProtocolVersion,
  );

  testWidgets('a hosting device is listed and one tap starts connecting',
      (tester) async {
    DiscoveredHost? picked;
    await tester.pumpWidget(
      wrap(
        SftpSiteManagerView(
          sites: const [],
          loading: false,
          connectingSiteId: null,
          onConnect: (_) {},
          onEdit: (_) {},
          onDelete: (_) {},
          onNew: () {},
          onThisDevice: () {},
          nearby: const [nearby],
          discoveryAvailable: true,
          onQuickConnect: (host) => picked = host,
        ),
      ),
    );

    expect(find.text('On this network'), findsOneWidget);
    expect(find.text('Stephan-PC'), findsOneWidget);
    expect(find.text('192.168.2.10:7420'), findsOneWidget);

    await tester.tap(find.text('Connect'));
    expect(picked, nearby);
  });

  testWidgets('the section stays out of the way where discovery cannot run',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        SftpSiteManagerView(
          sites: const [],
          loading: false,
          connectingSiteId: null,
          onConnect: (_) {},
          onEdit: (_) {},
          onDelete: (_) {},
          onNew: () {},
          onThisDevice: () {},
          onQuickConnect: (_) {},
        ),
      ),
    );
    expect(find.text('On this network'), findsNothing);
  });

  testWidgets('quick connect needs the password and keeps the port editable',
      (tester) async {
    QuickConnectAnswer? answer;
    var closed = false;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              answer = await promptQuickConnect(
                context,
                deviceName: 'Stephan-PC',
                address: '192.168.2.10',
                port: 7420,
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.at(0)).controller!.text, '7420');

    // No password yet: refused in place, dialog stays open.
    await tester.tap(find.widgetWithText(LumaPrimaryButton, 'Connect'));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(find.text('Type the pairing password shown on Stephan-PC.'), findsOneWidget);

    await tester.enterText(fields.at(0), '51000');
    await tester.enterText(fields.at(1), 'abcd efgh jkmn pqrs tvwx');
    await tester.tap(find.widgetWithText(LumaPrimaryButton, 'Connect'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(answer!.port, 51000);
    expect(answer!.secret, 'abcd efgh jkmn pqrs tvwx');
    expect(answer!.save, isFalse);
  });
}

