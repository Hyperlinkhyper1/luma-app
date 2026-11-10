import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_inventory_api.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_market_repository.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_purchase_history_api.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_steam_session.dart';
import 'package:luma/features/plugins/installed/steam_tools/data/steam_database.dart';
import 'package:luma/features/plugins/installed/steam_tools/ui/cs2_shared.dart';
import 'package:luma/features/plugins/installed/steam_tools/ui/cs2_tracked_tab.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/theme/luma_theme.dart';

const _id = '76561198012345678';
const _hash = 'Revolution Case';

class _NoScheduleStorageGuard extends StorageGuardService {
  @override
  void scheduleRefresh() {}
}

class _Session implements Cs2SteamSession {
  @override
  Future<String?> signedInSteamId() async => _id;

  @override
  Future<void> signOut() async {}

  @override
  Future<Cs2InventoryPage> load(Uri uri) async => Cs2InventoryPage(
    200,
    jsonEncode({
      'success': true,
      'total_count': 1,
      'pagesize': 1,
      'events': [
        {
          'event_type': 4,
          'listingid': '1',
          'purchaseid': '2',
          'time_event': 1794000000,
        },
      ],
      'purchases': {
        '1_2': {
          'steamid_purchaser': _id,
          'paid_amount': 100,
          'paid_fee': 15,
          'currencyid': '2001',
          'asset': {
            'appid': 730,
            'contextid': '2',
            'new_id': 'owned-copy',
            'amount': '1',
          },
        },
      },
    }),
  );
}

void main() {
  testWidgets(
    'purchase import updates portfolio profit and loss without reopening',
    (tester) async {
      StorageGuardService.instance = _NoScheduleStorageGuard();
      final db = SteamDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      final repository = Cs2MarketRepository(
        db,
        purchaseHistoryApi: Cs2PurchaseHistoryApi(
          usdPerUnit: (_) async => null,
        ),
        fetchOfflineSnapshot: () async => null,
      );
      try {
        await tester.runAsync(() async {
          await db.addImportedCs2Item(
            Cs2MarketItemsCompanion.insert(
              marketHashName: _hash,
              skinId: 'case',
              displayName: _hash,
              weaponName: 'Container',
              rarityName: '',
              rarityColor: '#ffffff',
              imageUrl: '',
            ),
            '$_id:owned-copy',
          );
          await db.recordCs2Prices({_hash: 200}, observedAt: DateTime.now());
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: LumaTheme.dark,
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: Scaffold(
              body: Cs2TrackedBody(repository: repository, query: ''),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Cs2GainLossBadge), findsNothing);
        await tester.runAsync(
          () => repository.importPurchaseHistory(_id, _Session()),
        );
        await tester.pumpAndSettle();
        expect(find.text('+\$0.85'), findsWidgets);
        expect(find.text('+73.9%'), findsWidgets);
        await tester.runAsync(
          () => db.recordCs2Prices({_hash: 100}, observedAt: DateTime.now()),
        );
        await tester.pumpAndSettle();
        expect(find.text('-\$0.15'), findsWidgets);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        repository.dispose();
        await tester.runAsync(db.close);
        await tester.pump();
      }
    },
  );
}
