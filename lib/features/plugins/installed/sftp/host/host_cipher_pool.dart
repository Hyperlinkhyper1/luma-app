import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// The record cipher, and the worker isolates that run it for file chunks.
///
/// ChaCha20-Poly1305 rather than AES-GCM: the transfer runs in pure Dart, and
/// there GCM's GHASH made AES-GCM the whole bottleneck — around 15 MB/s to
/// seal a chunk on a desktop, several times less on a phone. ChaCha20-Poly1305
/// is about three times faster in the same code and just as strong (it is
/// what TLS 1.3 and WireGuard use), with the same 32-byte key, 12-byte nonce
/// and 16-byte tag, so nothing else about the channel changed.
///
/// Chunks are sealed and opened on a small pool of isolates, several at once.
/// That is safe because a record's nonce is fixed by its counter when the
/// record is *queued*, not when the work finishes — see [HostSecureChannel].
/// Callers keep the wire order; the pool only makes the work concurrent and
/// keeps it off the UI isolate, which used to stall for every chunk.
class HostCipherPool {
  HostCipherPool._();

  static final HostCipherPool instance = HostCipherPool._();

  static final Cipher cipher = Chacha20.poly1305Aead();

  /// Tag length appended to every sealed record.
  static const int macLength = 16;

  /// Records smaller than this — control messages, handshake replies — are
  /// done in place. A round trip to a worker costs more than they do.
  static const int inlineBelow = 32 * 1024;

  final List<_Worker> _workers = [];
  Future<void>? _starting;
  final Map<int, _Job> _jobs = {};
  int _nextJobId = 0;

  /// Encrypts [plain] and returns ciphertext followed by the tag.
  Future<Uint8List> seal(Uint8List key, Uint8List nonce, Uint8List plain) {
    if (plain.length < inlineBelow) return sealInline(key, nonce, plain);
    return _submit(seal: true, key: key, nonce: nonce, data: plain);
  }

  /// Checks and decrypts a record made by [seal]. Throws [SecretBoxAuthenticationError]
  /// (or a [StateError] from a worker) when it has been tampered with.
  Future<Uint8List> open(Uint8List key, Uint8List nonce, Uint8List record) {
    if (record.length < inlineBelow) return openInline(key, nonce, record);
    return _submit(seal: false, key: key, nonce: nonce, data: record);
  }

  static Future<Uint8List> sealInline(
    List<int> key,
    List<int> nonce,
    List<int> plain,
  ) async {
    final box = await cipher.encrypt(
      plain,
      secretKey: SecretKeyData(key),
      nonce: nonce,
    );
    final out = Uint8List(box.cipherText.length + macLength)
      ..setAll(0, box.cipherText)
      ..setAll(box.cipherText.length, box.mac.bytes);
    return out;
  }

  static Future<Uint8List> openInline(
    List<int> key,
    List<int> nonce,
    Uint8List record,
  ) async {
    if (record.length < macLength) {
      throw StateError('Record too short to be authentic.');
    }
    final split = record.length - macLength;
    final clear = await cipher.decrypt(
      SecretBox(
        Uint8List.sublistView(record, 0, split),
        nonce: nonce,
        mac: Mac(Uint8List.sublistView(record, split)),
      ),
      secretKey: SecretKeyData(key),
    );
    return clear is Uint8List ? clear : Uint8List.fromList(clear);
  }

  // ------------------------------------------------------------- workers

  /// A few cores is plenty: past four the network is the limit, and a phone
  /// needs the rest for everything else it is doing.
  static int get _poolSize =>
      (Platform.numberOfProcessors - 1).clamp(1, 4).toInt();

  Future<Uint8List> _submit({
    required bool seal,
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List data,
  }) async {
    await (_starting ??= _start());
    if (_workers.isEmpty) {
      // Isolates unavailable here; the work still has to happen.
      return seal
          ? sealInline(key, nonce, data)
          : openInline(key, nonce, data);
    }
    var worker = _workers.first;
    for (final candidate in _workers) {
      if (candidate.outstanding < worker.outstanding) worker = candidate;
    }
    final id = _nextJobId++;
    final job = _Job(worker);
    _jobs[id] = job;
    worker.outstanding++;
    worker.port.send([
      id,
      seal,
      key,
      nonce,
      TransferableTypedData.fromList([data]),
    ]);
    return job.completer.future;
  }

  Future<void> _start() async {
    final replies = RawReceivePort()
      // An idle pool must never be what keeps the app (or a test run) alive.
      ..keepIsolateAlive = false;
    final ready = <Completer<SendPort>>[];
    replies.handler = (Object? message) {
      if (message is SendPort) {
        for (final waiting in ready) {
          if (!waiting.isCompleted) {
            waiting.complete(message);
            return;
          }
        }
        return;
      }
      if (message is! List || message.isEmpty) return;
      final job = _jobs.remove(message[0] as int);
      if (job == null) return;
      job.worker.outstanding--;
      final result = message[1];
      if (result is TransferableTypedData) {
        job.completer.complete(result.materialize().asUint8List());
      } else {
        job.completer.completeError(StateError('$result'));
      }
    };

    for (var i = 0; i < _poolSize; i++) {
      final portReady = Completer<SendPort>();
      ready.add(portReady);
      try {
        await Isolate.spawn(
          _workerMain,
          replies.sendPort,
          debugName: 'luma host cipher $i',
        );
        _workers.add(_Worker(await portReady.future));
      } catch (_) {
        // Fewer workers is still faster than none.
        break;
      }
    }
  }
}

class _Worker {
  _Worker(this.port);

  final SendPort port;
  int outstanding = 0;
}

class _Job {
  _Job(this.worker);

  final _Worker worker;
  final Completer<Uint8List> completer = Completer<Uint8List>();
}

/// Runs on a worker isolate: seals or opens one record per message, and
/// answers with the result or the reason it failed.
void _workerMain(SendPort replies) {
  final inbox = RawReceivePort();
  replies.send(inbox.sendPort);
  inbox.handler = (Object? message) async {
    final job = message as List;
    final id = job[0] as int;
    try {
      final seal = job[1] as bool;
      final key = job[2] as Uint8List;
      final nonce = job[3] as Uint8List;
      final data = (job[4] as TransferableTypedData).materialize().asUint8List();
      final out = seal
          ? await HostCipherPool.sealInline(key, nonce, data)
          : await HostCipherPool.openInline(key, nonce, data);
      replies.send([id, TransferableTypedData.fromList([out])]);
    } catch (e) {
      replies.send([id, '$e']);
    }
  };
}
