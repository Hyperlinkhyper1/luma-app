import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/steam_tools/ui/cs2_inventory_dialog.dart';

void main() {
  testWidgets('connects, refreshes and disconnects an inventory', (tester) async {
    String? profile;
    var refreshes = 0;
    var disconnected = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Cs2InventoryDialog(
          steamId: null,
          onConnect: (value) async {
            profile = value;
            return null;
          },
          onRefresh: () async {
            refreshes++;
            return null;
          },
          onDisconnect: () async {
            disconnected = true;
          },
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), '76561198000000000');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(profile, '76561198000000000');
    expect(find.text('Inventory imported.'), findsOneWidget);

    await tester.tap(find.text('Refresh inventory'));
    await tester.pumpAndSettle();
    expect(refreshes, 1);

    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(disconnected, isTrue);
    expect(find.text('Connect'), findsOneWidget);
  });
}
