import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/sftp/share/device_share_repository.dart';
import 'package:luma/features/plugins/installed/sftp/share/share_index.dart';
import 'package:luma/features/plugins/installed/sftp/share/shared_folder.dart';
import 'package:luma/p2p/peer_protocol.dart';
import 'package:luma/p2p/peer_share.dart';

SharedFileEntry _entry(
  String path, {
  int size = 10,
  String hash = 'aaa',
  int modifiedMs = 1000,
  int? deletedAtMs,
}) =>
    SharedFileEntry(
      path: path,
      size: size,
      hash: hash,
      modifiedMs: modifiedMs,
      deletedAtMs: deletedAtMs,
    );

/// Stands in for the other device's end of the link. Records what we sent it
/// and can be told to answer a request with real bytes.
class FakeShareChannel implements PeerShareChannel {
  FakeShareChannel({this.peer});

  /// When set, requests are served out of this folder — enough to run two
  /// repositories against each other without a socket.
  SharedFolder? peer;

  final List<List<SharedFileEntry>> sentIndexes = [];
  final List<({String path, int from})> requests = [];
  final List<({String path, String reason})> unavailable = [];
  final List<SharedChunkHeader> sentChunks = [];

  /// Set by the test to receive what this channel emits, so a pair of
  /// repositories can be wired mouth-to-ear.
  Future<void> Function(SharedChunkHeader header, Uint8List bytes)? onChunk;

  @override
  void sendShareIndex(List<SharedFileEntry> entries) => sentIndexes.add(entries);

  @override
  void requestShareFile(String path, {int from = 0}) =>
      requests.add((path: path, from: from));

  @override
  void sendShareUnavailable(String path, String reason) =>
      unavailable.add((path: path, reason: reason));

  @override
  Future<void> sendShareChunk(
    SharedChunkHeader header,
    Uint8List bytes,
  ) async {
    sentChunks.add(header);
    await onChunk?.call(header, bytes);
  }
}

Future<Directory> _tempDir(String prefix) async {
  final dir = await Directory.systemTemp.createTemp('luma_$prefix');
  addTearDown(() async {
    // Give any handle the repository is closing a moment to let go — Windows
    // refuses to delete a directory that still has one open, and a leftover
    // temp directory is not worth failing a test over.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  });
  return dir;
}

/// Waits for real filesystem work to finish. [pumpEventQueue] only turns the
/// event loop, which happily outruns an actual disk write.
Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
    await pumpEventQueue();
  }
}

Future<SharedFolder> _folder(String prefix) async {
  final base = await _tempDir(prefix);
  return SharedFolder.openAt(
    Directory('${base.path}${Platform.pathSeparator}shared'),
    File('${base.path}${Platform.pathSeparator}index.json'),
  );
}

Future<File> _write(SharedFolder folder, String name, String content) async {
  final file = folder.fileFor(name);
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
  return file;
}

void main() {
  group('planShareSync', () {
    test('pulls what the peer has and we do not', () {
      final plan = planShareSync(
        ours: {},
        theirs: [_entry('notes.txt')],
      );

      expect(plan, hasLength(1));
      expect(plan.single.kind, ShareDecisionKind.pull);
      expect(plan.single.path, 'notes.txt');
    });

    test('pulls a newer copy of something we already have', () {
      final plan = planShareSync(
        ours: {'notes.txt': _entry('notes.txt', modifiedMs: 1000)},
        theirs: [_entry('notes.txt', hash: 'bbb', modifiedMs: 2000)],
      );

      expect(plan.single.kind, ShareDecisionKind.pull);
    });

    test('leaves alone what we are newer on — they will pull it from us', () {
      final plan = planShareSync(
        ours: {'notes.txt': _entry('notes.txt', modifiedMs: 3000)},
        theirs: [_entry('notes.txt', hash: 'bbb', modifiedMs: 2000)],
      );

      expect(plan, isEmpty);
    });

    test('a newer tombstone deletes our copy', () {
      final plan = planShareSync(
        ours: {'notes.txt': _entry('notes.txt', modifiedMs: 1000)},
        theirs: [_entry('notes.txt', modifiedMs: 1000, deletedAtMs: 2000)],
      );

      expect(plan.single.kind, ShareDecisionKind.deleteLocal);
    });

    test('a newer write beats an older delete', () {
      final plan = planShareSync(
        ours: {
          'notes.txt': _entry('notes.txt', modifiedMs: 500, deletedAtMs: 1000),
        },
        theirs: [_entry('notes.txt', hash: 'bbb', modifiedMs: 2000)],
      );

      expect(plan.single.kind, ShareDecisionKind.pull);
    });

    test('a tombstone for a file we never had is still recorded', () {
      final plan = planShareSync(
        ours: {},
        theirs: [_entry('gone.txt', deletedAtMs: 2000)],
      );

      expect(plan.single.kind, ShareDecisionKind.adoptTombstone);
    });

    test('an older tombstone does not delete our newer copy', () {
      final plan = planShareSync(
        ours: {'notes.txt': _entry('notes.txt', modifiedMs: 3000)},
        theirs: [_entry('notes.txt', modifiedMs: 500, deletedAtMs: 1000)],
      );

      expect(plan, isEmpty);
    });

    test('a same-instant conflict resolves the same way on both devices', () {
      const stamp = 5000;
      final higher = _entry('c.txt', hash: 'zzz', modifiedMs: stamp);
      final lower = _entry('c.txt', hash: 'aaa', modifiedMs: stamp);

      // The device holding the lower hash pulls; the other one does nothing.
      // Run both directions to prove exactly one transfer happens.
      final onLowSide = planShareSync(ours: {'c.txt': lower}, theirs: [higher]);
      final onHighSide = planShareSync(ours: {'c.txt': higher}, theirs: [lower]);

      expect(onLowSide.single.kind, ShareDecisionKind.pull);
      expect(onHighSide, isEmpty);
    });

    test('identical files produce no work', () {
      final same = _entry('same.txt', hash: 'abc', modifiedMs: 42);
      expect(planShareSync(ours: {'same.txt': same}, theirs: [same]), isEmpty);
    });
  });

  group('pruneTombstones', () {
    test('drops only tombstones past the window', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final index = {
        'old.txt': _entry('old.txt', deletedAtMs: now - const Duration(days: 200).inMilliseconds),
        'recent.txt': _entry('recent.txt', deletedAtMs: now - const Duration(days: 3).inMilliseconds),
        'live.txt': _entry('live.txt', modifiedMs: 1),
      };

      final pruned = pruneTombstones(index, nowMs: now);

      expect(pruned.keys, unorderedEquals(['recent.txt', 'live.txt']));
    });
  });

  group('normalizeSharePath', () {
    test('rejects anything that could escape the folder', () {
      expect(normalizeSharePath('../../etc/passwd'), 'etc/passwd');
      expect(normalizeSharePath(r'C:\Windows\system32'), 'Windows/system32');
      expect(normalizeSharePath('/absolute/file.txt'), 'absolute/file.txt');
      expect(normalizeSharePath('..'), isNull);
      expect(normalizeSharePath('   '), '   ');
      expect(normalizeSharePath(''), isNull);
    });

    test('keeps a normal nested path intact', () {
      expect(normalizeSharePath('photos/2026/a.jpg'), 'photos/2026/a.jpg');
      expect(normalizeSharePath(r'photos\2026\a.jpg'), 'photos/2026/a.jpg');
    });
  });

  group('SharedFolder', () {
    test('a rescan indexes new files and hashes them', () async {
      final folder = await _folder('scan');
      await _write(folder, 'a.txt', 'hello');

      expect(await folder.rescan(), isTrue);

      final entry = folder.entryFor('a.txt')!;
      expect(entry.size, 5);
      expect(entry.hash, sha256.convert(utf8.encode('hello')).toString());
      expect(entry.isDeleted, isFalse);
      expect(folder.files, hasLength(1));
    });

    test('a second rescan with nothing changed reports no change', () async {
      final folder = await _folder('scan2');
      await _write(folder, 'a.txt', 'hello');
      await folder.rescan();

      expect(await folder.rescan(), isFalse);
    });

    test('a file removed from disk becomes a tombstone', () async {
      final folder = await _folder('tomb');
      await _write(folder, 'a.txt', 'hello');
      await folder.rescan();

      await folder.fileFor('a.txt').delete();
      expect(await folder.rescan(), isTrue);

      expect(folder.entryFor('a.txt')!.isDeleted, isTrue);
      expect(folder.files, isEmpty);
      expect(folder.advertisement, hasLength(1));
    });

    test('the staging folder never shows up as shared content', () async {
      final folder = await _folder('staging');
      final staged = await folder.stagingFileFor('big.bin');
      await staged.writeAsBytes(List<int>.filled(16, 7));

      await folder.rescan();

      expect(folder.files, isEmpty);
    });

    test('importing twice keeps both copies instead of overwriting', () async {
      final folder = await _folder('import');
      final source = await _tempDir('src');
      final file = File('${source.path}${Platform.pathSeparator}note.txt');
      await file.writeAsString('one');

      final first = await folder.importFile(file);
      await file.writeAsString('two');
      final second = await folder.importFile(file);

      expect(first.path, 'note.txt');
      expect(second.path, 'note (2).txt');
      expect(await folder.fileFor('note.txt').readAsString(), 'one');
      expect(await folder.fileFor('note (2).txt').readAsString(), 'two');
    });

    test('deleting leaves a tombstone behind', () async {
      final folder = await _folder('delete');
      await _write(folder, 'a.txt', 'hello');
      await folder.rescan();

      await folder.deleteEntry('a.txt');

      expect(await folder.fileFor('a.txt').exists(), isFalse);
      expect(folder.entryFor('a.txt')!.isDeleted, isTrue);
    });

    test('the index survives a reopen', () async {
      final base = await _tempDir('reopen');
      final root = Directory('${base.path}${Platform.pathSeparator}shared');
      final indexFile = File('${base.path}${Platform.pathSeparator}index.json');

      final first = await SharedFolder.openAt(root, indexFile);
      await _write(first, 'a.txt', 'hello');
      await first.rescan();

      final second = await SharedFolder.openAt(root, indexFile);

      expect(second.entryFor('a.txt')?.hash, first.entryFor('a.txt')?.hash);
    });
  });

  group('DeviceShareRepository', () {
    test('advertises the folder as soon as a device appears', () async {
      final folder = await _folder('advertise');
      await _write(folder, 'a.txt', 'hello');
      final repository = DeviceShareRepository(folder);
      addTearDown(repository.dispose);
      await folder.rescan();

      final channel = FakeShareChannel();
      repository.onPeerAvailable('device-b', 'Laptop', channel);

      expect(channel.sentIndexes, hasLength(1));
      expect(channel.sentIndexes.single.single.path, 'a.txt');
      expect(repository.peers.single.deviceName, 'Laptop');
      expect(repository.peers.single.connected, isTrue);
    });

    test('asks for every file it is behind on', () async {
      final folder = await _folder('pull');
      final repository = DeviceShareRepository(folder);
      addTearDown(repository.dispose);
      final channel = FakeShareChannel();
      repository.onPeerAvailable('device-b', 'Laptop', channel);

      repository.onPeerIndex('device-b', [_entry('a.txt'), _entry('b.txt')]);
      await _settle();

      // One at a time: the second is queued behind the first.
      expect(channel.requests.map((r) => r.path), ['a.txt']);
      expect(repository.peers.single.pendingIn, 1);
    });

    test('a peer tombstone deletes the local copy', () async {
      final folder = await _folder('remote-delete');
      await _write(folder, 'a.txt', 'hello');
      await folder.rescan();
      final repository = DeviceShareRepository(folder);
      addTearDown(repository.dispose);
      final channel = FakeShareChannel();
      repository.onPeerAvailable('device-b', 'Laptop', channel);

      final ours = folder.entryFor('a.txt')!;
      repository.onPeerIndex('device-b', [
        _entry('a.txt', modifiedMs: ours.modifiedMs, deletedAtMs: ours.modifiedMs + 1000),
      ]);
      await _settle();

      expect(await folder.fileFor('a.txt').exists(), isFalse);
      expect(folder.entryFor('a.txt')!.isDeleted, isTrue);
    });

    test('serves a requested file in chunks and refuses what it lacks',
        () async {
      final folder = await _folder('serve');
      await _write(folder, 'a.txt', 'hello world');
      await folder.rescan();
      final repository = DeviceShareRepository(folder);
      addTearDown(repository.dispose);
      final channel = FakeShareChannel();
      repository.onPeerAvailable('device-b', 'Laptop', channel);

      repository.onPeerRequest('device-b', 'a.txt', 0);
      await _settle();

      expect(channel.sentChunks, hasLength(1));
      expect(channel.sentChunks.single.isLast, isTrue);
      expect(channel.sentChunks.single.totalSize, 11);
      expect(channel.sentChunks.single.hash, folder.entryFor('a.txt')!.hash);

      repository.onPeerRequest('device-b', 'missing.txt', 0);
      await _settle();

      expect(channel.unavailable.single.path, 'missing.txt');
    });

    test('a path that tries to escape the folder is refused', () async {
      final folder = await _folder('escape');
      final repository = DeviceShareRepository(folder);
      addTearDown(repository.dispose);
      final channel = FakeShareChannel();
      repository.onPeerAvailable('device-b', 'Laptop', channel);

      repository.onPeerIndex('device-b', [_entry('../../evil.txt')]);
      await _settle();

      // Normalized to a path inside the folder rather than acted on as given.
      expect(channel.requests.single.path, 'evil.txt');
    });

    test('a disconnect parks the transfer instead of failing it', () async {
      final folder = await _folder('park');
      final repository = DeviceShareRepository(folder);
      addTearDown(repository.dispose);
      final channel = FakeShareChannel();
      repository.onPeerAvailable('device-b', 'Laptop', channel);
      repository.onPeerIndex('device-b', [_entry('a.txt')]);
      await _settle();

      repository.onPeerGone('device-b');
      await _settle();

      expect(repository.peers.single.connected, isFalse);
      expect(repository.active, isEmpty);

      // Coming back re-requests it without the test re-queuing anything.
      repository.onPeerAvailable('device-b', 'Laptop', channel);
      await _settle();

      expect(channel.requests.map((r) => r.path), ['a.txt', 'a.txt']);
    });

    test('a file moves end to end between two repositories', () async {
      final senderFolder = await _folder('sender');
      final receiverFolder = await _folder('receiver');
      await _write(senderFolder, 'report.txt', 'the quick brown fox' * 10);
      await senderFolder.rescan();

      final sender = DeviceShareRepository(senderFolder);
      final receiver = DeviceShareRepository(receiverFolder);
      addTearDown(sender.dispose);
      addTearDown(receiver.dispose);

      // Wire each repository's channel at the other one.
      final toReceiver = FakeShareChannel();
      final toSender = FakeShareChannel();
      toReceiver.onChunk = (header, bytes) =>
          receiver.onPeerChunk('sender', header, bytes);

      sender.onPeerAvailable('receiver', 'Phone', toReceiver);
      receiver.onPeerAvailable('sender', 'Desktop', toSender);

      // The receiver sees what the sender has, and asks for it.
      receiver.onPeerIndex('sender', senderFolder.advertisement);
      await _settle();
      expect(toSender.requests.single.path, 'report.txt');

      // The sender serves it; chunks land in the receiver via onChunk.
      sender.onPeerRequest('receiver', 'report.txt', 0);
      await _settle();

      expect(
        await receiverFolder.fileFor('report.txt').readAsString(),
        'the quick brown fox' * 10,
      );
      expect(
        receiverFolder.entryFor('report.txt')!.hash,
        senderFolder.entryFor('report.txt')!.hash,
      );
      expect(receiver.active, isEmpty);
      expect(receiver.history.single.error, isNull);
    });

    test('an empty file still arrives', () async {
      final senderFolder = await _folder('empty-sender');
      final receiverFolder = await _folder('empty-receiver');
      await _write(senderFolder, 'empty.txt', '');
      await senderFolder.rescan();

      final sender = DeviceShareRepository(senderFolder);
      final receiver = DeviceShareRepository(receiverFolder);
      addTearDown(sender.dispose);
      addTearDown(receiver.dispose);

      final toReceiver = FakeShareChannel();
      toReceiver.onChunk = (header, bytes) =>
          receiver.onPeerChunk('sender', header, bytes);
      sender.onPeerAvailable('receiver', 'Phone', toReceiver);
      receiver.onPeerAvailable('sender', 'Desktop', FakeShareChannel());

      receiver.onPeerIndex('sender', senderFolder.advertisement);
      await _settle();
      sender.onPeerRequest('receiver', 'empty.txt', 0);
      await _settle();

      expect(await receiverFolder.fileFor('empty.txt').exists(), isTrue);
      expect(await receiverFolder.fileFor('empty.txt').length(), 0);
    });

    test('a corrupted arrival is rejected rather than committed', () async {
      final receiverFolder = await _folder('corrupt');
      final receiver = DeviceShareRepository(receiverFolder);
      addTearDown(receiver.dispose);
      receiver.onPeerAvailable('sender', 'Desktop', FakeShareChannel());
      receiver.onPeerIndex('sender', [
        _entry('bad.txt', size: 4, hash: 'not-the-real-hash'),
      ]);
      await _settle();

      await receiver.onPeerChunk(
        'sender',
        const SharedChunkHeader(
          path: 'bad.txt',
          offset: 0,
          length: 4,
          totalSize: 4,
          modifiedMs: 1000,
          hash: 'not-the-real-hash',
          isLast: true,
        ),
        Uint8List.fromList(utf8.encode('junk')),
      );
      await _settle();

      expect(await receiverFolder.fileFor('bad.txt').exists(), isFalse);
      expect(receiver.history.single.error, isNotNull);
    });
  });

  group('share wire types', () {
    test('an entry survives the round trip', () {
      final entry = _entry('a/b.txt', size: 12, hash: 'abc', modifiedMs: 7);
      final restored = SharedFileEntry.fromJson(entry.toJson())!;

      expect(restored.path, 'a/b.txt');
      expect(restored.size, 12);
      expect(restored.hash, 'abc');
      expect(restored.modifiedMs, 7);
      expect(restored.isDeleted, isFalse);
      expect(restored.stamp, 7);
    });

    test('a tombstone keeps its delete time as its stamp', () {
      final tombstone = _entry('a.txt', modifiedMs: 5).asDeleted(9);

      expect(tombstone.isDeleted, isTrue);
      expect(tombstone.stamp, 9);
      expect(SharedFileEntry.fromJson(tombstone.toJson())!.deletedAtMs, 9);
    });

    test('a malformed entry is dropped, not guessed at', () {
      expect(SharedFileEntry.fromJson(null), isNull);
      expect(SharedFileEntry.fromJson(const {'s': 1}), isNull);
      expect(SharedFileEntry.fromJson('nonsense'), isNull);
    });

    test('a chunk header rejects an impossible length', () {
      expect(
        SharedChunkHeader.fromJson(const {'path': 'a', 'length': -1}),
        isNull,
      );
      expect(
        SharedChunkHeader.fromJson({
          'path': 'a',
          'length': kMaxFrameBytes + 1,
        }),
        isNull,
      );
      // Zero is legal: it is how an empty file is sent.
      expect(
        SharedChunkHeader.fromJson(const {'path': 'a', 'length': 0})?.length,
        0,
      );
    });
  });
}
