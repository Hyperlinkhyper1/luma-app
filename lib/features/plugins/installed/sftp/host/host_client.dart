import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import '../file_times.dart';
import '../sftp_paths.dart';
import '../sftp_session.dart';
import '../sftp_site.dart';
import 'host_crypto.dart';
import 'host_protocol.dart';

/// The browsing half of device-to-device transfer: a [SftpSession] whose
/// other end is another luma device running [SftpHostServer].
///
/// Everything the remote pane, the context menus and the transfer queue do
/// goes through the same methods they call on an SSH connection, so nothing
/// above this class knows which kind it has.
///
/// The socket is opened straight to the address the user typed and every byte
/// on it is sealed by [HostSecureChannel]. No luma server is involved, so this
/// never touches `GatedServerClient`.
class LumaHostSession extends SftpSession {
  LumaHostSession._(
    this._socket,
    this._subscription,
    this._reader,
    this._channel, {
    required this.site,
    required this.hostName,
    required this.rootName,
    required this.readOnly,
  });

  final Socket _socket;

  /// A socket is a single-subscription stream: the handshake already listened
  /// to it, so the session takes that subscription over and swaps the handlers
  /// rather than listening again.
  final StreamSubscription<Uint8List> _subscription;

  /// The same reader the handshake used — it may hold the first bytes of the
  /// next frame, and a fresh one would lose them.
  final HostFrameReader _reader;

  final HostSecureChannel _channel;

  @override
  final SftpSite site;

  /// What the host calls itself, for the pane's title.
  final String hostName;

  /// The name of the folder the host is sharing.
  final String rootName;

  /// True when the host is sharing read-only. Write ops still get checked at
  /// the host — this is only so the client can fail fast with a clear reason.
  final bool readOnly;

  /// The host's shared folder is the whole world this connection can see, so
  /// its root is also home.
  @override
  String get homeDirectory => RemotePath.separator;

  final _pending = <int, Completer<Map<String, dynamic>>>{};

  /// Listing batches that arrived ahead of their request's reply.
  final _listParts = <int, List<Object?>>{};
  final _downloads = <int, _Download>{};
  final _closed = Completer<void>();

  var _isClosed = false;
  int _nextId = 1;
  Future<void> _sendChain = Future.value();

  @override
  bool get isClosed => _isClosed;

  @override
  Future<void> get done => _closed.future;

  String? _closeReason;

  @override
  String? get closeReason => _closeReason;

  /// Opens a connection to the luma device described by [site], with [secret]
  /// as the pairing password shown on that device's screen.
  ///
  /// When the host has to ask its user first, [onWaitingForApproval] is called
  /// with the host's name, and the returned future only completes once the
  /// person there presses Allow — a device is never handed back as connected
  /// while it is still waiting to be let in.
  static Future<SftpSession> connect({
    required SftpSite site,
    String? secret,
    Duration timeout = const Duration(seconds: 20),
    void Function(String hostName)? onWaitingForApproval,
  }) async {
    final host = site.host.trim();
    if (host.isEmpty) {
      throw SftpConnectionException('This device has no address.');
    }
    final password = secret ?? '';
    if (password.isEmpty) {
      throw SftpConnectionException(
        'Type the pairing password shown on that device.',
        isAuthFailure: true,
      );
    }

    final Socket socket;
    try {
      socket = await Socket.connect(host, site.port, timeout: timeout);
    } on SocketException catch (e) {
      throw SftpConnectionException(
        'Could not reach $host on port ${site.port}. Check that the other '
        'device is still showing its pairing screen and that both are on the '
        'same network.\n${e.osError?.message ?? e.message}',
      );
    } on TimeoutException {
      throw SftpConnectionException(
        'Timed out connecting to $host on port ${site.port}.',
      );
    }
    socket.setOption(SocketOption.tcpNoDelay, true);

    // The handshake runs over the raw socket before the session exists, so it
    // gets its own small reader and its own subscription; both are handed over
    // once the channel is up.
    final reader = HostFrameReader();
    final frames = <Uint8List>[];
    Completer<Uint8List>? waiting;
    Object? failure;

    void deliver(Uint8List frame) {
      final pending = waiting;
      if (pending != null && !pending.isCompleted) {
        waiting = null;
        pending.complete(frame);
      } else {
        frames.add(frame);
      }
    }

    void fail(Object error) {
      failure ??= error;
      final pending = waiting;
      waiting = null;
      if (pending != null && !pending.isCompleted) pending.completeError(error);
    }

    final subscription = socket.listen(
      (data) {
        try {
          reader.add(data).forEach(deliver);
        } catch (e) {
          fail(e);
        }
      },
      onError: fail,
      onDone: () => fail(
        const HostAuthException('That device closed the connection.'),
      ),
      cancelOnError: false,
    );

    Future<Uint8List> nextFrame() {
      if (failure != null) return Future.error(failure!);
      if (frames.isNotEmpty) return Future.value(frames.removeAt(0));
      final completer = Completer<Uint8List>();
      waiting = completer;
      return completer.future;
    }

    HostSecureChannel? channel;
    try {
      final result = await HostHandshake.connectAsClient(
        password: password,
        deviceName: _localName(),
        readControl: () async {
          final frame = decodeFrame(await nextFrame());
          if (!frame.isControl) {
            throw const HostProtocolException('Expected a handshake message.');
          }
          return frame.control!;
        },
        writeControl: (message) async {
          socket.add(frameBytes(encodeControlFrame(message)));
          await socket.flush();
        },
      ).timeout(kHostHandshakeTimeout);
      channel = result.channel;

      // The first sealed records say whether this device is in. Until the
      // host says so, nothing else will be answered.
      await _awaitAdmission(
        channel: result.channel,
        nextFrame: nextFrame,
        onWaiting: () => onWaitingForApproval?.call(result.hello.hostName),
      ).timeout(kHostApprovalTimeout + const Duration(seconds: 15));

      final session = LumaHostSession._(
        socket,
        subscription,
        reader,
        result.channel,
        site: site,
        hostName: result.hello.hostName,
        rootName: result.hello.rootName,
        readOnly: result.hello.readOnly,
      );

      // Take the subscription over before replaying, so nothing that arrives
      // in between is handed to the handshake's dead handlers.
      session._takeOver();
      // Anything that arrived between the handshake ending and the session
      // taking over is replayed in order — dropping it would desynchronise the
      // record counter and kill the connection on the next frame.
      for (final frame in frames) {
        session._onFrame(frame);
      }
      return session;
    } on HostAuthException catch (e) {
      await subscription.cancel();
      socket.destroy();
      throw SftpConnectionException(e.message, isAuthFailure: e.isAuthFailure);
    } on TimeoutException {
      await subscription.cancel();
      socket.destroy();
      throw SftpConnectionException(
        channel == null
            ? 'That device did not answer in time. Make sure it is still '
                'hosting.'
            : 'Nobody allowed this device in on the other end in time. Ask '
                'them to press Allow, then connect again.',
      );
    } on SftpConnectionException {
      await subscription.cancel();
      socket.destroy();
      rethrow;
    } catch (e) {
      await subscription.cancel();
      socket.destroy();
      throw SftpConnectionException('Could not connect to that device.\n$e');
    }
  }

  static Future<void> _awaitAdmission({
    required HostSecureChannel channel,
    required Future<Uint8List> Function() nextFrame,
    required void Function() onWaiting,
  }) async {
    while (true) {
      final frame = decodeFrame(await channel.open(await nextFrame()));
      final message = frame.control;
      if (message == null) {
        throw const HostProtocolException('Expected to be let in first.');
      }
      if (message[kWaitKey] == true) {
        onWaiting();
        continue;
      }
      if (message[kAdmitKey] == true) return;
      throw SftpConnectionException(
        message['e']?.toString() ?? 'That device did not let this one in.',
      );
    }
  }

  static String _localName() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'A luma device';
    }
  }

  // ---------------------------------------------------------------- wire

  /// Swaps the handshake's handlers on the existing subscription for the
  /// session's own.
  void _takeOver() {
    _subscription
      ..onData((data) {
        try {
          for (final frame in _reader.add(data)) {
            _onFrame(frame);
          }
        } catch (e) {
          _tearDown(e);
        }
      })
      ..onError(_tearDown)
      ..onDone(
        () => _tearDown(
          SftpConnectionException('That device closed the connection.'),
        ),
      );
  }

  /// Frames are handled strictly in arrival order — the record counter has no
  /// room for gaps — so each one is chained onto the last. Opening them is
  /// not: each open() takes its counter the moment the frame arrives, so the
  /// decryption of several frames runs in parallel on the cipher pool while
  /// the chain still consumes the results in order.
  Future<void> _frameChain = Future.value();

  /// Frames received but not yet handled. Past [kHostPipelineDepth] twice
  /// over the socket is paused, so TCP slows the host down instead of a fast
  /// download piling up in memory ahead of a slow disk.
  int _unhandled = 0;

  void _onFrame(Uint8List body) {
    if (_isClosed) return;
    final opened = _channel.open(body)..ignore();
    _unhandled++;
    if (_unhandled >= kHostPipelineDepth * 2 && !_subscription.isPaused) {
      _subscription.pause();
    }
    _frameChain = _frameChain
        .then((_) async {
          try {
            await _handleFrame(await opened);
          } finally {
            _unhandled--;
            if (_unhandled < kHostPipelineDepth && _subscription.isPaused) {
              _subscription.resume();
            }
          }
        })
        .catchError((Object e) {
          _tearDown(e);
        });
  }

  Future<void> _handleFrame(Uint8List plain) async {
    if (_isClosed) return;
    final frame = decodeFrame(plain);
    if (!frame.isControl) {
      final download = _downloads[frame.chunkId];
      if (download == null) return;
      try {
        await download.write(frame.chunk!);
      } catch (e) {
        // A full disk or a locked destination ends this download, not the
        // whole connection. The host is told to stop sending it.
        download.fail('The file could not be saved here: $e');
        unawaited(
          _send(
            encodeControlFrame(hostRequest(frame.chunkId!, HostOp.readStop)),
          ).catchError((_) {}),
        );
      }
      return;
    }

    final message = frame.control!;
    final id = (message['i'] as num?)?.toInt() ?? 0;

    final event = message['ev']?.toString();
    if (event == kEventListPart) {
      final batch = message['es'];
      if (batch is List) _listParts.putIfAbsent(id, () => []).addAll(batch);
      return;
    }
    if (event != null) {
      final download = _downloads[id];
      if (event == kEventEof) {
        download?.finish();
      } else {
        download?.fail(
          message['e']?.toString() ?? 'The transfer stopped unexpectedly.',
        );
      }
      return;
    }

    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) return;
    if (message['ok'] == true) {
      completer.complete(message);
    } else {
      completer.completeError(
        SftpConnectionException(
          message['e']?.toString() ?? 'That device refused the request.',
        ),
      );
    }
  }

  /// Sends one request and waits for its reply.
  Future<Map<String, dynamic>> _request(
    HostOp op, [
    Map<String, dynamic> fields = const {},
  ]) {
    final id = _nextId++;
    return _requestWithId(id, op, fields);
  }

  Future<Map<String, dynamic>> _requestWithId(
    int id,
    HostOp op, [
    Map<String, dynamic> fields = const {},
  ]) {
    if (_isClosed) {
      return Future.error(
        SftpConnectionException('The connection to that device is closed.'),
      );
    }
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    unawaited(
      _send(encodeControlFrame(hostRequest(id, op, fields))).catchError((
        Object e,
      ) {
        _pending.remove(id);
        if (!completer.isCompleted) completer.completeError(e);
      }),
    );
    return completer.future;
  }

  /// Sends without waiting for a reply — chunks, and the stop that ends a
  /// download early.
  Future<void> _send(Uint8List plain) {
    // Sealing starts now, off the chain, so several records can be sealing
    // at once; seal() fixed this record's nonce in call order, and the chain
    // writes them in that same order.
    final sealed = _isClosed ? null : (_channel.seal(plain)..ignore());
    final next = _sendChain.then((_) async {
      if (_isClosed || sealed == null) return;
      final body = await sealed;
      if (_isClosed) return;
      _socket.add(frameBytes(body));
      await _socket.flush();
    });
    _sendChain = next.catchError((_) {});
    return next;
  }

  void _tearDown(Object error) {
    if (_isClosed) return;
    _isClosed = true;
    _closeReason = error is SftpConnectionException
        ? error.message
        : error is HostProtocolException
            ? error.message
            : '$error';
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
    for (final download in _downloads.values) {
      download.fail('$error');
    }
    _downloads.clear();
    if (!_closed.isCompleted) _closed.complete();
    _socket.destroy();
  }

  // ----------------------------------------------------------------- ops

  @override
  Future<List<SftpEntry>> list(String path) async {
    final normalized = RemotePath.normalize(path);
    final id = _nextId++;
    final Map<String, dynamic> reply;
    List<Object?> earlier;
    try {
      reply = await _requestWithId(id, HostOp.list, {'p': normalized});
    } finally {
      earlier = _listParts.remove(id) ?? const [];
    }
    final raw = reply['es'];
    if (raw is! List) {
      throw SftpConnectionException('That device sent a folder we could not read.');
    }
    final entries = <SftpEntry>[];
    for (final item in [...earlier, ...raw]) {
      if (item is! Map<String, dynamic>) continue;
      entries.add(_toEntry(HostEntry.fromJson(item), normalized));
    }
    entries.sort(SftpSession.compareEntries);
    return entries;
  }

  @override
  Future<SftpEntry> statEntry(String path) async {
    final normalized = RemotePath.normalize(path);
    final reply = await _request(HostOp.stat, {'p': normalized});
    final raw = reply['e'];
    if (raw is! Map<String, dynamic>) {
      throw SftpConnectionException('That item could not be read.');
    }
    return _toEntry(HostEntry.fromJson(raw), RemotePath.parent(normalized));
  }

  SftpEntry _toEntry(HostEntry entry, String directory) => SftpEntry(
        name: entry.name,
        path: RemotePath.join(directory, entry.name),
        isDirectory: entry.isDirectory,
        isLink: entry.isLink,
        size: entry.size,
        modified: entry.modifiedMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(entry.modifiedMs!),
        mode: entry.mode,
      );

  @override
  Future<void> makeDirectory(String path) async {
    _refuseIfReadOnly();
    await _request(HostOp.makeDirectory, {'p': RemotePath.normalize(path)});
  }

  @override
  Future<void> rename(String from, String to) async {
    _refuseIfReadOnly();
    await _request(HostOp.rename, {
      'f': RemotePath.normalize(from),
      't': RemotePath.normalize(to),
    });
  }

  @override
  Future<void> removeFile(String path) async {
    _refuseIfReadOnly();
    await _request(HostOp.removeFile, {'p': RemotePath.normalize(path)});
  }

  @override
  Future<void> removeEmptyDirectory(String path) async {
    _refuseIfReadOnly();
    await _request(HostOp.removeDirectory, {'p': RemotePath.normalize(path)});
  }

  @override
  Future<void> chmod(String path, int mode) async {
    _refuseIfReadOnly();
    await _request(HostOp.chmod, {
      'p': RemotePath.normalize(path),
      'm': mode & 0x1ff,
    });
  }

  void _refuseIfReadOnly() {
    if (!readOnly) return;
    throw SftpConnectionException(
      '$hostName is sharing this folder read-only, so it cannot be changed '
      'from here.',
    );
  }

  @override
  Future<void> download(
    String remotePath,
    File destination, {
    void Function(int bytes)? onProgress,
    TransferCancelToken? cancelToken,
  }) async {
    final normalized = RemotePath.normalize(remotePath);
    final parent = destination.parent;
    if (!await parent.exists()) await parent.create(recursive: true);

    final id = _nextId++;
    final sink = destination.openWrite();
    final download = _Download(sink: sink, onProgress: onProgress);
    // Registered before the request goes out: the host starts streaming as
    // soon as it has answered, and a chunk that arrived before this map entry
    // existed would be dropped.
    _downloads[id] = download;

    cancelToken?.attach(() {
      download.cancel();
      unawaited(
        _send(encodeControlFrame(hostRequest(id, HostOp.readStop))).catchError(
          (_) {},
        ),
      );
    });

    var failed = true;
    var times = const FileTimes();
    try {
      final opened = await _requestWithId(
        id,
        HostOp.readOpen,
        {'p': normalized, 'o': 0},
      );
      times = FileTimes.fromWire(opened['t']);
      if (cancelToken?.isCancelled ?? false) throw const TransferCancelled();
      await download.done;
      failed = false;
    } finally {
      _downloads.remove(id);
      cancelToken?.attach(null);
      try {
        await sink.close();
      } catch (_) {
        // The failure below is the one worth reporting.
      }
      if (failed || (cancelToken?.isCancelled ?? false)) {
        // A half-written file is worse than none: the pane would show it at
        // the wrong size and it would look like it transferred.
        try {
          if (await destination.exists()) await destination.delete();
        } catch (_) {}
      }
    }
    if (cancelToken?.isCancelled ?? false) throw const TransferCancelled();
    // After the sink is closed: closing it would otherwise bump the modified
    // time straight back to now.
    await times.applyTo(destination);
  }

  @override
  Future<void> upload(
    File source,
    String remotePath, {
    void Function(int bytes)? onProgress,
    TransferCancelToken? cancelToken,
  }) async {
    _refuseIfReadOnly();
    final normalized = RemotePath.normalize(remotePath);
    final id = _nextId++;
    await _requestWithId(id, HostOp.writeOpen, {'p': normalized});

    var sent = 0;
    var cancelled = false;
    final inFlight = Queue<Future<void>>();
    RandomAccessFile? handle;
    try {
      // Read in full protocol chunks (openRead() hands out 64 KiB, four times
      // the frames for the same file) and keep several in flight, so the
      // disk, the cipher and the network overlap instead of taking turns.
      handle = await source.open();
      while (true) {
        if (cancelToken?.isCancelled ?? false) {
          cancelled = true;
          break;
        }
        final bytes = await handle.read(kHostChunkBytes);
        if (bytes.isEmpty) break;
        inFlight.add(_send(encodeChunkFrame(id, bytes)));
        if (inFlight.length >= kHostPipelineDepth) {
          await inFlight.removeFirst();
        }
        sent += bytes.length;
        onProgress?.call(sent);
      }
      await Future.wait(inFlight);
    } finally {
      cancelToken?.attach(null);
      await handle?.close();
    }

    if (cancelled) {
      // Close it so the host lets go of the handle, then remove the partial
      // file it was building.
      try {
        await _requestWithId(id, HostOp.writeClose);
        await _request(HostOp.removeFile, {'p': normalized});
      } catch (_) {
        // Best effort — the connection may already be gone.
      }
      throw const TransferCancelled();
    }

    await _requestWithId(id, HostOp.writeClose, {
      't': (await FileTimes.of(source)).toWire(),
    });
  }

  @override
  void close() {
    if (_isClosed) return;
    _isClosed = true;
    for (final download in _downloads.values) {
      download.cancel();
    }
    _downloads.clear();
    // Anything still waiting on a reply would otherwise wait forever.
    final closed = SftpConnectionException('The connection was closed.');
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(closed);
    }
    _pending.clear();
    if (!_closed.isCompleted) _closed.complete();
    _socket.destroy();
  }
}

/// One download in flight: where the bytes go, and how the frame loop tells
/// the awaiting `download()` that it finished.
class _Download {
  _Download({required this.sink, this.onProgress});

  final IOSink sink;
  final void Function(int bytes)? onProgress;
  final _completer = Completer<void>();

  /// Flush once this much has been handed to the sink. `IOSink.add` buffers
  /// without waiting for the disk, so on a fast network and a slow disk the
  /// whole file would otherwise pile up in memory before any of it landed.
  static const _flushEvery = 4 * 1024 * 1024;

  int _written = 0;
  int _sinceFlush = 0;
  var _cancelled = false;

  Future<void> get done => _completer.future;

  Future<void> write(Uint8List bytes) async {
    if (_cancelled || _completer.isCompleted) return;
    sink.add(bytes);
    _written += bytes.length;
    _sinceFlush += bytes.length;
    onProgress?.call(_written);
    if (_sinceFlush >= _flushEvery) {
      _sinceFlush = 0;
      await sink.flush();
    }
  }

  void finish() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void fail(String message) {
    if (!_completer.isCompleted) {
      _completer.completeError(SftpConnectionException(message));
    }
  }

  void cancel() {
    _cancelled = true;
    if (!_completer.isCompleted) _completer.complete();
  }
}
