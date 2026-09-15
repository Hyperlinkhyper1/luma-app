import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/sync/sync_collections.dart';
import 'package:luma/sync/sync_service.dart';

/// A collection that records nothing — the gate is the thing under test, not
/// what the collection holds.
JsonStoreSyncCollection collection(String id, {String? minPlanId}) {
  return JsonStoreSyncCollection(
    id: id,
    label: id == 'airline_tycoon' ? 'Airline Tycoon' : id,
    icon: Icons.flight_takeoff_rounded,
    minPlanId: minPlanId,
    listenable: ChangeNotifier(),
    exporter: () async => const <String, Object?>{},
    importer: (_) async {},
  );
}

Future<SyncService> makeService({
  required String plan,
  int? limit,
}) async {
  final sync = SyncService(
    syncCollectionLimit: () => limit,
    currentPlanId: () => plan,
    collections: [
      collection('airline_tycoon', minPlanId: 'orbit'),
      collection('notes'),
    ],
  );
  addTearDown(sync.dispose);
  await sync.init();
  await sync.setLocalAccount(
    email: 'plan-gate@example.com',
    password: 'plan-gate-test-password',
  );
  return sync;
}

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('plan-gated collections', () {
    test('a free plan is refused, and told which plan it needs', () async {
      final sync = await makeService(plan: 'core');
      expect(sync.planAllowsCollection('airline_tycoon'), isFalse);

      await expectLater(
        sync.enableCollection('airline_tycoon'),
        throwsA(isA<SyncPlanRequiredException>()
            .having((e) => e.requiredPlanId, 'requiredPlanId', 'orbit')
            .having((e) => e.label, 'label', 'Airline Tycoon')),
      );
      expect(sync.isEnabled('airline_tycoon'), isFalse);
    });

    test('Orbit may enable it', () async {
      final sync = await makeService(plan: 'orbit');
      expect(sync.planAllowsCollection('airline_tycoon'), isTrue);
      await sync.enableCollection('airline_tycoon');
      expect(sync.isEnabled('airline_tycoon'), isTrue);
    });

    test('Nova inherits everything Orbit unlocks', () async {
      final sync = await makeService(plan: 'nova');
      expect(sync.planAllowsCollection('airline_tycoon'), isTrue);
      await sync.enableCollection('airline_tycoon');
      expect(sync.isEnabled('airline_tycoon'), isTrue);
    });

    test('an ungated collection is unaffected on every plan', () async {
      // The regression guard for the twenty-odd collections that already
      // exist: adding minPlanId must not have changed any of them.
      for (final plan in ['core', 'orbit', 'nova']) {
        final sync = await makeService(plan: plan);
        expect(sync.planAllowsCollection('notes'), isTrue,
            reason: 'notes should sync on $plan');
        await sync.enableCollection('notes');
        expect(sync.isEnabled('notes'), isTrue);
      }
    });

    test('with no plan callback a gated collection fails closed', () async {
      // A gate that cannot tell what plan this device is on must refuse the
      // paid thing rather than wave it through. Ungated collections are
      // unaffected either way, so no existing construction site changes
      // behaviour — only a deliberately gated one, and main.dart always
      // supplies the callback.
      final sync = SyncService(
        collections: [
          collection('airline_tycoon', minPlanId: 'orbit'),
          collection('notes'),
        ],
      );
      addTearDown(sync.dispose);
      await sync.init();
      expect(sync.planAllowsCollection('airline_tycoon'), isFalse);
      expect(sync.planAllowsCollection('notes'), isTrue);
    });

    test('an unknown collection id is allowed rather than refused', () async {
      final sync = await makeService(plan: 'core');
      expect(sync.planAllowsCollection('does_not_exist'), isTrue);
    });
  });

  group('which gate speaks first', () {
    test('the plan gate wins over the count gate', () async {
      // A free user at their collection limit should be told they need Orbit,
      // not the misleading "you are out of slots".
      final sync = await makeService(plan: 'core', limit: 0);
      await expectLater(
        sync.enableCollection('airline_tycoon'),
        throwsA(isA<SyncPlanRequiredException>()),
      );
    });

    test('the count gate still fires for an ungated collection', () async {
      final sync = await makeService(plan: 'core', limit: 0);
      await expectLater(
        sync.enableCollection('notes'),
        throwsA(isA<SyncLimitExceededException>()),
      );
    });
  });

  group('downgrade honesty', () {
    test('a collection enabled on Nova stops syncing once the plan lapses',
        () async {
      // The reason the gate is re-checked rather than trusted at enable time:
      // otherwise subscribing once would grant sync forever.
      var plan = 'nova';
      final sync = SyncService(
        syncCollectionLimit: () => null,
        currentPlanId: () => plan,
        collections: [collection('airline_tycoon', minPlanId: 'orbit')],
      );
      addTearDown(sync.dispose);
      await sync.init();
      await sync.setLocalAccount(
        email: 'downgrade@example.com',
        password: 'downgrade-test-password',
      );

      await sync.enableCollection('airline_tycoon');
      expect(sync.isEnabled('airline_tycoon'), isTrue);
      expect(sync.peerState().containsKey('airline_tycoon'), isTrue);

      plan = 'core';

      // The stored toggle is untouched, but nothing may leave the device.
      expect(sync.isEnabled('airline_tycoon'), isTrue);
      expect(sync.planAllowsCollection('airline_tycoon'), isFalse);
      expect(sync.peerState().containsKey('airline_tycoon'), isFalse);
      expect(await sync.buildPeerSnapshot('airline_tycoon'), isNull);
    });

    test('re-subscribing restores it without re-enabling by hand', () async {
      var plan = 'core';
      final sync = SyncService(
        syncCollectionLimit: () => null,
        currentPlanId: () => plan,
        collections: [collection('airline_tycoon', minPlanId: 'orbit')],
      );
      addTearDown(sync.dispose);
      await sync.init();
      await sync.setLocalAccount(
        email: 'resubscribe@example.com',
        password: 'resubscribe-test-password',
      );

      plan = 'orbit';
      await sync.enableCollection('airline_tycoon');
      plan = 'core';
      expect(sync.peerState().containsKey('airline_tycoon'), isFalse);
      plan = 'orbit';
      expect(sync.peerState().containsKey('airline_tycoon'), isTrue);
    });
  });
}
