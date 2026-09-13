import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/home/home_layout.dart';
import 'package:luma/features/home/home_repository.dart';
import 'package:luma/sync/sync_collections.dart';
import 'package:luma/sync/sync_service.dart';

void main() {
  test(
    'encrypted home snapshots sync to laptops and are declined by phones',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'luma-home-sync-',
      );
      final repos = <HomeRepository>[];
      final services = <SyncService>[];
      addTearDown(() async {
        for (final service in services) {
          service.dispose();
        }
        for (final repo in repos) {
          repo.dispose();
        }
        await directory.delete(recursive: true);
      });

      Future<SyncService> device(String name, String family) async {
        final repo = HomeRepository(
          family: family,
          file: () async => File('${directory.path}/$name.json'),
        );
        repos.add(repo);
        await repo.ready;
        final sync = SyncService(
          syncCollectionLimit: () => 0,
          collections: [
            JsonStoreSyncCollection(
              id: repo.collectionId,
              label: 'Home',
              icon: Icons.home,
              listenable: repo,
              exporter: repo.exportData,
              importer: repo.importData,
            ),
          ],
        );
        services.add(sync);
        await sync.init();
        await sync.setLocalAccount(
          email: 'home-sync@example.com',
          password: 'home-sync-test-password',
        );
        return sync;
      }

      final desktop = await device('desktop', 'desktop');
      final laptop = await device('laptop', 'desktop');
      final phone = await device('phone', 'phone');
      final custom = HomeLayout(
        heroMetric: 'custom',
        heroLabel: 'My focus',
        heroText: 'A calmer morning',
        columns: 12,
        tiles: [
          const HomeTile(
            id: 'work-clock',
            kind: 'clock',
            x: 5,
            y: 6,
            w: 4,
            h: 4,
          ),
        ],
      );
      await repos.first.save(custom);
      final sealed = await desktop.buildPeerSnapshot('home_desktop');
      expect(sealed, isNotNull);
      expect(
        await laptop.applyPeerSnapshot(
          'home_desktop',
          sealed!.sealed,
          sealed.savedAtMs,
        ),
        true,
      );
      expect(repos[1].layout.toJson(), custom.toJson());
      final phoneBefore = repos.last.layout.toJson();
      expect(
        await phone.applyPeerSnapshot(
          'home_desktop',
          sealed.sealed,
          sealed.savedAtMs,
        ),
        false,
      );
      expect(repos.last.layout.toJson(), phoneBefore);
      expect(await phone.buildPeerSnapshot('home_desktop'), isNull);
      expect(phone.peerState().keys, ['home_phone']);
      expect(desktop.enabledSyncCollectionCount, 0);
      await desktop.disableCollection('home_desktop');
      expect(desktop.isEnabled('home_desktop'), true);
      await expectLater(
        desktop.enableCollection('notes'),
        throwsA(isA<SyncLimitExceededException>()),
      );
      expect(desktop.serverReady, false);
    },
  );
}
