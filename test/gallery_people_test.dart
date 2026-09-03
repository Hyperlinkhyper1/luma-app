import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_people.dart';

/// A vector nudged slightly off [base] — different photos of the same person
/// never produce byte-identical fingerprints.
List<double> _near(List<double> base, {double jitter = 0.02}) => [
      for (var i = 0; i < base.length; i++)
        base[i] + (i.isEven ? jitter : -jitter),
    ];

void main() {
  group('cosineSimilarity', () {
    test('identical vectors are perfectly similar', () {
      expect(cosineSimilarity([1, 2, 3], [1, 2, 3]), closeTo(1, 1e-9));
    });

    test('opposite vectors are perfectly dissimilar', () {
      expect(cosineSimilarity([1, 0], [-1, 0]), closeTo(-1, 1e-9));
    });

    test('orthogonal vectors score zero', () {
      expect(cosineSimilarity([1, 0], [0, 1]), closeTo(0, 1e-9));
    });

    test('is unaffected by magnitude, only direction', () {
      final a = cosineSimilarity([1, 2, 3], [2, 4, 6]);
      final b = cosineSimilarity([1, 2, 3], [10, 20, 30]);
      expect(a, closeTo(1, 1e-9));
      expect(a, closeTo(b, 1e-9));
    });

    test('mismatched lengths and empty vectors are handled, not thrown', () {
      expect(cosineSimilarity([], []), -1);
      expect(cosineSimilarity([1, 2], [1, 2, 3]), -1);
      expect(cosineSimilarity([0, 0], [1, 1]), -1);
    });
  });

  group('assignFaceToCluster', () {
    test('the first face always starts a new cluster', () {
      final clusters = <PersonCluster>[];
      final id = assignFaceToCluster(clusters, [1, 0, 0], nextId: () => 1);
      expect(id, 1);
      expect(clusters, hasLength(1));
      expect(clusters.single.count, 1);
    });

    test('a near-identical face joins the existing cluster', () {
      final clusters = <PersonCluster>[];
      var next = 0;
      final first = assignFaceToCluster(
        clusters, [1, 0, 0, 0],
        nextId: () => ++next,
      );
      final second = assignFaceToCluster(
        clusters, _near([1, 0, 0, 0]),
        nextId: () => ++next,
      );
      expect(second, first);
      expect(clusters, hasLength(1));
      expect(clusters.single.count, 2);
    });

    test('a clearly different face starts a second cluster', () {
      final clusters = <PersonCluster>[];
      var next = 0;
      final personA = assignFaceToCluster(
        clusters, [1, 0, 0, 0],
        nextId: () => ++next,
      );
      final personB = assignFaceToCluster(
        clusters, [0, 1, 0, 0],
        nextId: () => ++next,
      );
      expect(personA, isNot(personB));
      expect(clusters, hasLength(2));
    });

    test('three photos of two people sort into two clusters of the right size',
        () {
      final clusters = <PersonCluster>[];
      var next = 0;
      int assign(List<double> v) =>
          assignFaceToCluster(clusters, v, nextId: () => ++next);

      final a1 = assign([1, 0, 0, 0]);
      final b1 = assign([0, 0, 1, 0]);
      final a2 = assign(_near([1, 0, 0, 0]));

      expect(a2, a1);
      expect(a1, isNot(b1));
      expect(clusters, hasLength(2));
      expect(clusters.firstWhere((c) => c.id == a1).count, 2);
      expect(clusters.firstWhere((c) => c.id == b1).count, 1);
    });

    test('the centroid is the running mean, not just the last face', () {
      // Orthogonal vectors score 0 similarity — below any real threshold —
      // so a threshold of -2 (impossible to fail) is what forces the merge
      // this test actually wants to look at: given that two faces did land
      // in one cluster, is its centroid their mean, not just the newest one?
      final clusters = <PersonCluster>[];
      var next = 0;
      int assign(List<double> v) => assignFaceToCluster(
            clusters, v,
            nextId: () => ++next, threshold: -2,
          );

      assign([1, 0]);
      assign([0, 1]);
      final cluster = clusters.single;
      expect(cluster.centroid[0], closeTo(0.5, 1e-9));
      expect(cluster.centroid[1], closeTo(0.5, 1e-9));
    });

    test('a custom threshold can be made stricter or looser', () {
      final clusters = <PersonCluster>[];
      var next = 0;
      assignFaceToCluster(clusters, [1, 0, 0], nextId: () => ++next);

      // A moderately different vector: similar enough for a loose threshold,
      // not for a strict one.
      final middling = [0.9, 0.3, 0.0];
      final looseId = assignFaceToCluster(
        List.of(clusters), middling,
        nextId: () => ++next, threshold: 0.5,
      );
      final strictId = assignFaceToCluster(
        List.of(clusters), middling,
        nextId: () => ++next, threshold: 0.999,
      );
      expect(looseId, clusters.single.id);
      expect(strictId, isNot(clusters.single.id));
    });
  });

  group('PersonCluster', () {
    test('shows a numbered placeholder until it is named', () {
      const cluster = PersonCluster(id: 3, centroid: [1, 2], count: 1);
      expect(cluster.displayName, 'Person 3');
    });

    test('a set name takes over, trimmed', () {
      const named = PersonCluster(
        id: 3,
        centroid: [1, 2],
        count: 1,
        name: '  Sam  ',
      );
      // The constructor stores whatever it's given...
      expect(named.name, '  Sam  ');
      // ...but display trims it, and an unnamed cluster still falls back to
      // the numbered placeholder.
      expect(named.displayName, 'Sam');
      const unnamed = PersonCluster(id: 3, centroid: [1, 2], count: 1);
      expect(unnamed.displayName, 'Person 3');
      expect(unnamed.copyWith(name: 'Sam').displayName, 'Sam');
    });

    test('round-trips through JSON without losing anything', () {
      const cluster = PersonCluster(
        id: 5,
        centroid: [0.1, -0.2, 0.3],
        count: 7,
        name: 'Robin',
        coverKey: 'IMG_1@123',
      );
      final restored = PersonCluster.fromJson(cluster.toJson());
      expect(restored.id, cluster.id);
      expect(restored.centroid, cluster.centroid);
      expect(restored.count, cluster.count);
      expect(restored.name, cluster.name);
      expect(restored.coverKey, cluster.coverKey);
    });
  });

  group('GalleryPeopleStore persistence', () {
    late Directory temp;
    late GalleryPeopleStore store;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      temp = await Directory.systemTemp.createTemp('luma_people');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => temp.path,
      );
      store = GalleryPeopleStore();
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      if (temp.existsSync()) await temp.delete(recursive: true);
    });

    test('a fresh store has no one in it', () async {
      await store.load();
      expect(store.clusters, isEmpty);
    });

    test('assigning gives the new cluster its cover photo', () {
      final id = store.assign([1, 0, 0], coverKey: 'photo1');
      expect(store.byId(id)!.coverKey, 'photo1');
    });

    test('renaming is retrievable by id', () {
      final id = store.assign([1, 0, 0]);
      store.rename(id, 'Alex');
      expect(store.byId(id)!.displayName, 'Alex');
    });

    test('clusters and names survive a flush and reload', () async {
      final id = store.assign([1, 0, 0, 0], coverKey: 'cover.jpg');
      store.rename(id, 'Jordan');
      await store.flush();

      final reloaded = GalleryPeopleStore();
      await reloaded.load();
      final cluster = reloaded.byId(id)!;
      expect(cluster.displayName, 'Jordan');
      expect(cluster.coverKey, 'cover.jpg');
      expect(cluster.centroid, [1, 0, 0, 0]);
    });

    test('ids keep climbing across a reload rather than reusing old ones',
        () async {
      store.assign([1, 0, 0]);
      store.assign([0, 1, 0]);
      await store.flush();

      final reloaded = GalleryPeopleStore();
      await reloaded.load();
      final thirdId = reloaded.assign([0, 0, 1]);
      expect(thirdId, isNot(anyOf(1, 2)));
    });
  });
}
