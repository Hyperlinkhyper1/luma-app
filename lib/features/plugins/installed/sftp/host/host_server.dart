import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../sftp_paths.dart';
import 'host_crypto.dart';
import 'host_jail.dart';
import 'host_protocol.dart';

/// Whether the host is listening, and why not when it isn't.
enum HostStatus { stopped, starting, running, failed }

/// What a connected device is allowed to do. Chosen by the user before
/// hosting starts and fixed for the life of the connection — a device is told
/// which one it got in the handshake, and every write op re-checks it rather
/// than trusting that the client hid the buttons.
enum HostAccess {
  /// Browse and download. Nothing on this device can be changed.
  readOnly,

  /// Browse, download, upload, rename and delete inside the shared folder.
  readWrite,
}

/// One device currently attached to this host.
class HostClient {
  HostClient._({
    required this.id,
    required this.deviceName,
    required this.address,
    required this.connectedAt,
  });

  final int id;
  final String deviceName;

  /// The peer's IP as the socket reports it — not something the peer chose.
  final String address;

  final DateTime connectedAt;

  int bytesSent = 0;
  int bytesReceived = 0;

  /// Set while the user has not yet allowed this device in, when the host is
  /// running with [SftpHostServer.requireApproval] on.
  bool awaitingApproval = false;

  String get label => '$deviceName · $address';
}

/// Makes this device the one others connect to: it opens a TCP listener, and
/// serves exactly one folder over the protocol in [host_protocol.dart].
///
/// The whole surface is deliberately narrow. There is no shell, no command
/// execution, no way to name a path outside the shared folder ([HostJail] is
/// the only route from a request to a file), and no way in at all without the
/// pairing password ([HostHandshake]). Nothing here talks to a luma server,
/// so none of it goes near `GatedServerClient` — the socket is between the two
/// devices and nothing else.
///
/// The listener is owned by the SFTP page's state, which the app shell keeps
/// alive in its `IndexedStack`. Hosting therefore survives navigating to
/// another plugin — which is the point, since a transfer should not die
/// because the user looked at something else — and ends when the user presses
/// Stop or the app shuts the page down.
class SftpHostServer extends ChangeNotifier {
  SftpHostServer();

  /// Refuse more than this many devices at once. Each one costs a socket and
  /// a file handle or two; the cap is what stops a flood from exhausting
  /// either.
  static const int maxClients = 8;

  /// Wrong passwords tolerated from one address before it is put in the sin
  /// bin for [_lockoutDuration]. Guessing the generated password would take
  /// astronomically many tries; this makes even that impossible in practice
  /// and blunts anything else pointed at the port.
  static const int maxFailuresPerAddress = 5;
  static const Duration _lockoutDuration = Duration(minutes: 10);

  ServerSocket? _socket;
  HostJail? _jail;

  HostStatus _status = HostStatus.stopped;
  String? _error;

  Directory? _directory;
  int _port = kDefaultHostPort;
  String _password = '';
  HostAccess _access = HostAccess.readOnly;
  bool _requireApproval = true;

  final List<_HostConnection> _connections = [];
  final Map<String, _FailureRecord> _failures = {};
  int _nextClientId = 1;

  /// A pending approval, surfaced so the page can show a prompt.
  final Queue<_HostConnection> _pending = Queue();

  HostStatus get status => _status;
  String? get error => _error;
  bool get isRunning => _status == HostStatus.running;

  Directory? get directory => _directory;
  int get port => _port;
  String get password => _password;
  HostAccess get access => _access;
  bool get requireApproval => _requireApproval;

  /// The folder's display name — what the other device shows as the site
  /// title, and the only part of the path that leaves this machine.
  String get rootName {
    final path = _directory?.path;
    if (path == null) return 'Shared';
    final parts = path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty);
    return parts.isEmpty ? 'Shared' : parts.last;
  }

  List<HostClient> get clients =>
      List.unmodifiable([for (final c in _connections) c.client]);

  /// The device waiting to be let in, if any.
  HostClient? get pendingApproval =>
      _pending.isEmpty ? null : _pending.first.client;

  int get clientCount => _connections.length;

  /// The addresses another device can reach this one on, best first.
  ///
  /// Loopback is left out: it is never the answer to "what do I type on my
  /// phone", and showing it invites the user to try it and fail.
  static Future<List<String>> localAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      final addresses = <String>[];
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.isLoopback) continue;
          addresses.add(address.address);
        }
      }
      // A 192.168.x / 10.x address is the one that works on a home network,
      // so it goes first; 169.254.x link-local addresses go last.
      addresses.sort((a, b) => _addressRank(a).compareTo(_addressRank(b)));
      return addresses;
    } catch (_) {
      return const [];
    }
  }

  static int _addressRank(String address) {
    if (address.startsWith('192.168.')) return 0;
    if (address.startsWith('10.')) return 1;
    if (RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(address)) return 2;
    if (address.startsWith('169.254.')) return 9;
    return 5;
  }

  /// Starts listening.
  ///
  /// [password] defaults to a fresh generated one. A password the user typed
  /// is checked against [kMinPairingPasswordLength] here rather than only in
  /// the dialog, so there is no path to a host protected by two characters.
  Future<void> start({
    required Directory directory,
    int port = kDefaultHostPort,
    String? password,
    HostAccess access = HostAccess.readOnly,
    bool requireApproval = true,
  }) async {
    await stop();

    final secret = password ?? generatePairingPassword();
    if (secret.length < kMinPairingPasswordLength) {
      _status = HostStatus.failed;
      _error = 'A pairing password needs at least '
          '$kMinPairingPasswordLength characters.';
      _notify();
      return;
    }

    _status = HostStatus.starting;
    _error = null;
    _directory = directory;
    _port = port;
    _password = secret;
    _access = access;
    _requireApproval = requireApproval;
    _failures.clear();
    _notify();

    try {
      _jail = await HostJail.forDirectory(directory);
      final socket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        port,
        shared: false,
      );
      _socket = socket;
      _port = socket.port;
      _status = HostStatus.running;
      socket.listen(
        _accept,
        onError: (Object e) {
          _error = 'The listener stopped: $e';
          _status = HostStatus.failed;
          _notify();
        },
        cancelOnError: false,
      );
    } on SocketException catch (e) {
      _status = HostStatus.failed;
      _error = e.osError?.errorCode == 10048 || e.osError?.errorCode == 98
          ? 'Port $port is already in use on this device. Pick another one.'
          : 'Could not listen on port $port. ${e.osError?.message ?? e.message}';
    } catch (e) {
      _status = HostStatus.failed;
      _error = 'Could not start hosting. $e';
    }
    _notify();
  }

  /// Stops listening and drops every connected device.
  Future<void> stop() async {
    final socket = _socket;
    _socket = null;
    _jail = null;
    _pending.clear();
    for (final connection in _connections.toList()) {
      await connection.close();
    }
    _connections.clear();
    await socket?.close();
    if (_status != HostStatus.stopped) {
      _status = HostStatus.stopped;
      _error = null;
      _notify();
    }
  }

  /// Issues a new pairing password. Devices already connected keep working —
  /// their keys were derived at handshake time — but nothing new can join with
  /// the old one.
  void rotatePassword() {
    if (!isRunning) return;
    _password = generatePairingPassword();
    _failures.clear();
    _notify();
  }

  /// Lets the device at the front of the queue in.
  void approvePending() {
    if (_pending.isEmpty) return;
    final connection = _pending.removeFirst();
    connection.client.awaitingApproval = false;
    connection.settleApproval(true);
    _notify();
  }

  /// Turns the waiting device away.
  void rejectPending() {
    if (_pending.isEmpty) return;
    _pending.removeFirst().settleApproval(false);
    _notify();
  }

  /// Drops one connected device without stopping the host.
  Future<void> disconnectClient(int id) async {
    final connection = _connections.firstWhereOrNull((c) => c.client.id == id);
    if (connection == null) return;
    await connection.close();
  }

  // ------------------------------------------------------------- internals

  Future<void> _accept(Socket socket) async {
    if (_disposed) {
      socket.destroy();
      return;
    }
    final address = socket.remoteAddress.address;

    if (_isLockedOut(address)) {
      // Closed without a word: an address that is guessing gets no signal
      // about whether the host is even still there.
      socket.destroy();
      return;
    }
    if (_connections.length >= maxClients) {
      socket.destroy();
      return;
    }

    final jail = _jail;
    final directory = _directory;
    if (jail == null || directory == null) {
      socket.destroy();
      return;
    }

    socket.setOption(SocketOption.tcpNoDelay, true);
    final connection = _HostConnection(
      server: this,
      socket: socket,
      jail: jail,
      clientId: _nextClientId++,
      address: address,
    );
    _connections.add(connection);
    _notify();

    try {
      await connection.run();
    } catch (_) {
      // run() already recorded whatever it needs to; the connection is going
      // away either way.
    } finally {
      _connections.remove(connection);
      _pending.remove(connection);
      _notify();
    }
  }

  bool _isLockedOut(String address) {
    final record = _failures[address];
    if (record == null) return false;
    if (DateTime.now().difference(record.last) > _lockoutDuration) {
      _failures.remove(address);
      return false;
    }
    return record.count >= maxFailuresPerAddress;
  }

  void _recordFailure(String address) {
    final record = _failures.putIfAbsent(address, _FailureRecord.new);
    if (DateTime.now().difference(record.last) > _lockoutDuration) {
      record.count = 0;
    }
    record
      ..count += 1
      ..last = DateTime.now();
  }

  void _clearFailures(String address) => _failures.remove(address);

  /// Parks [connection] until the user answers. Returns false when they say
  /// no, or when hosting stops while it waits.
  Future<bool> _awaitApproval(_HostConnection connection) {
    final completer = Completer<bool>();
    connection.approval = completer;
    connection.client.awaitingApproval = true;
    _pending.add(connection);
    _notify();
    return completer.future;
  }

  void _touched() => _notify();

  /// A connection that is mid-handshake when the page closes still lands here
  /// afterwards, so the guard is what keeps a late socket from notifying a
  /// disposed server.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}

class _FailureRecord {
  int count = 0;
  DateTime last = DateTime.now();
}

/// One attached device: its socket, its keys, and the ops it is running.
class _HostConnection {
  _HostConnection({
    required this.server,
    required this.socket,
    required this.jail,
    required int clientId,
    required String address,
  }) : client = HostClient._(
          id: clientId,
          deviceName: 'Connecting…',
          address: address,
          connectedAt: DateTime.now(),
        );

  final SftpHostServer server;
  final Socket socket;
  final HostJail jail;

  HostClient client;

  /// Held while the user is being asked about this device. Answered exactly
  /// once — by the user, or by [close] when the connection or the host goes
  /// away first — via [settleApproval].
  Completer<bool>? approval;

  /// Answers the pending approval, if it has not been answered already.
  void settleApproval(bool allowed) {
    final completer = approval;
    approval = null;
    if (completer != null && !completer.isCompleted) completer.complete(allowed);
  }

  final _reader = HostFrameReader();
  final _frames = Queue<Uint8List>();
  Completer<Uint8List>? _waiting;
  Object? _fatal;

  HostSecureChannel? _channel;
  var _closed = false;

  /// Sends are chained: sealing bumps a nonce counter, so two of them must
  /// never be in flight at once.
  Future<void> _sendChain = Future.value();

  /// Download streams the client has open, so a `readstop` can end one.
  final Map<int, _ReadStream> _reads = {};

  /// Upload handles, keyed by the request id that opened them.
  final Map<int, _WriteStream> _writes = {};

  bool get _readOnly => server.access == HostAccess.readOnly;

  Future<void> run() async {
    final subscription = socket.listen(
      _onData,
      onError: (Object e) => _fail(e),
      onDone: () => _fail(const HostProtocolException('The device hung up.')),
      cancelOnError: false,
    );

    try {
      await _handshake().timeout(kHostHandshakeTimeout);
      if (server.requireApproval) {
        final allowed = await server._awaitApproval(this);
        if (!allowed) {
          await _send(encodeControlFrame({
            'i': 0,
            'ok': false,
            'e': 'The other device did not allow this connection.',
          }));
          return;
        }
      }
      server._touched();
      await _serve();
    } on TimeoutException {
      // A socket that connects and then says nothing holds a slot; dropping it
      // is what keeps maxClients meaningful.
    } on HostAuthException catch (e) {
      if (e.isAuthFailure) server._recordFailure(client.address);
    } catch (_) {
      // Any protocol error ends the connection; nothing to add.
    } finally {
      await subscription.cancel();
      await close();
    }
  }

  Future<void> _handshake() async {
    // Both the seed and the salt are fresh for this one connection and are
    // dropped when it ends, so the keys it used cannot be recovered from
    // anything the host keeps.
    final seed = secureRandomBytes(32);
    final hello = HostHello(
      version: kHostProtocolVersion,
      hostName: await _deviceName(),
      salt: secureRandomBytes(HostCrypto.saltLength),
      publicKey: await publicKeyForSeed(seed),
      rootName: server.rootName,
      readOnly: _readOnly,
    );

    final result = await HostHandshake.acceptAsHost(
      password: server.password,
      hello: hello,
      hostPrivateSeed: seed,
      readControl: _readPlainControl,
      writeControl: (message) => _send(encodeControlFrame(message)),
    );

    _channel = result.channel;
    client = HostClient._(
      id: client.id,
      deviceName: result.deviceName,
      address: client.address,
      connectedAt: client.connectedAt,
    );
    server._clearFailures(client.address);
  }

  static Future<String> _deviceName() async {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'A luma device';
    }
  }

  /// The main loop once the channel is up: one frame at a time, each
  /// dispatched without blocking the next.
  Future<void> _serve() async {
    while (!_closed) {
      final body = await _nextFrame();
      final channel = _channel!;
      final plain = await channel.open(body);
      client.bytesReceived += body.length;
      final frame = decodeFrame(plain);

      if (frame.isControl) {
        // Requests are handled off the loop so a slow one (a large directory,
        // a download) does not stall the ops behind it.
        unawaited(_handleControl(frame.control!));
      } else {
        await _handleChunk(frame.chunkId!, frame.chunk!);
      }
    }
  }

  Future<void> _handleControl(Map<String, dynamic> message) async {
    final id = (message['i'] as num?)?.toInt() ?? 0;
    final op = HostOp.parse(message['op']?.toString());
    if (op == null) {
      await _reply(hostError(id, 'This host does not support that request.'));
      return;
    }

    try {
      switch (op) {
        case HostOp.list:
          await _opList(id, message);
        case HostOp.stat:
          await _opStat(id, message);
        case HostOp.makeDirectory:
          await _opMakeDirectory(id, message);
        case HostOp.rename:
          await _opRename(id, message);
        case HostOp.removeFile:
          await _opRemoveFile(id, message);
        case HostOp.removeDirectory:
          await _opRemoveDirectory(id, message);
        case HostOp.chmod:
          await _opChmod(id, message);
        case HostOp.readOpen:
          await _opRead(id, message);
        case HostOp.readStop:
          _reads.remove(id)?.cancelled = true;
        case HostOp.writeOpen:
          await _opWriteOpen(id, message);
        case HostOp.writeClose:
          await _opWriteClose(id);
      }
    } on HostAccessDenied catch (e) {
      await _reply(hostError(id, e.message));
    } on FileSystemException catch (e) {
      await _reply(hostError(id, _describeFileError(e)));
    } catch (e) {
      await _reply(hostError(id, 'That did not work: $e'));
    }
  }

  // ----------------------------------------------------------------- ops

  Future<void> _opList(int id, Map<String, dynamic> message) async {
    final path = await jail.resolve(_path(message, 'p'), mustExist: true);
    final directory = Directory(path);
    if (!await directory.exists()) {
      await _reply(hostError(id, 'That folder is no longer there.'));
      return;
    }
    final entries = <Map<String, dynamic>>[];
    await for (final entity in directory.list(followLinks: false)) {
      final name = entity.path.split(RegExp(r'[\\/]')).last;
      if (name.isEmpty) continue;
      try {
        // The listing is taken with followLinks: false, so a link arrives as
        // a Link entity. stat() below follows it — which is what tells us
        // whether it points at a directory — but the entity type is the only
        // thing that says it was a link at all.
        final isLink = entity is Link;
        final stat = await entity.stat();
        entries.add(
          HostEntry(
            name: name,
            isDirectory: stat.type == FileSystemEntityType.directory,
            isLink: isLink,
            size: stat.size < 0 ? 0 : stat.size,
            modifiedMs: stat.modified.millisecondsSinceEpoch,
            mode: Platform.isWindows ? null : stat.mode & 0x1ff,
          ).toJson(),
        );
      } catch (_) {
        // A file that vanished or cannot be stat'd mid-listing is skipped
        // rather than failing the whole directory.
      }
    }
    await _reply(hostOk(id, {'es': entries}));
  }

  Future<void> _opStat(int id, Map<String, dynamic> message) async {
    final remote = _path(message, 'p');
    final path = await jail.resolve(remote, mustExist: true);
    final stat = await FileStat.stat(path);
    if (stat.type == FileSystemEntityType.notFound) {
      await _reply(hostError(id, 'That item is not there.'));
      return;
    }
    await _reply(hostOk(id, {
      'e': HostEntry(
        name: RemotePath.basename(remote),
        isDirectory: stat.type == FileSystemEntityType.directory,
        isLink: stat.type == FileSystemEntityType.link,
        size: stat.size < 0 ? 0 : stat.size,
        modifiedMs: stat.modified.millisecondsSinceEpoch,
        mode: Platform.isWindows ? null : stat.mode & 0x1ff,
      ).toJson(),
    }));
  }

  Future<void> _opMakeDirectory(int id, Map<String, dynamic> message) async {
    if (await _refuseWrite(id)) return;
    final path = await jail.resolve(_path(message, 'p'));
    await Directory(path).create();
    await _reply(hostOk(id));
  }

  Future<void> _opRename(int id, Map<String, dynamic> message) async {
    if (await _refuseWrite(id)) return;
    final from = await jail.resolve(_path(message, 'f'), mustExist: true);
    final to = await jail.resolve(_path(message, 't'));
    if (await Directory(from).exists()) {
      await Directory(from).rename(to);
    } else {
      await File(from).rename(to);
    }
    await _reply(hostOk(id));
  }

  Future<void> _opRemoveFile(int id, Map<String, dynamic> message) async {
    if (await _refuseWrite(id)) return;
    final path = await jail.resolve(_path(message, 'p'), mustExist: true);
    await File(path).delete();
    await _reply(hostOk(id));
  }

  Future<void> _opRemoveDirectory(int id, Map<String, dynamic> message) async {
    if (await _refuseWrite(id)) return;
    final path = await jail.resolve(_path(message, 'p'), mustExist: true);
    // Non-recursive on purpose: the client walks the tree and deletes leaves
    // first, so a bug there can only ever remove what it listed, and a
    // recursive delete can never be triggered by one short message.
    await Directory(path).delete();
    await _reply(hostOk(id));
  }

  Future<void> _opChmod(int id, Map<String, dynamic> message) async {
    if (await _refuseWrite(id)) return;
    if (Platform.isWindows) {
      await _reply(hostError(
        id,
        'This device runs Windows, which has no POSIX permissions to set.',
      ));
      return;
    }
    final path = await jail.resolve(_path(message, 'p'), mustExist: true);
    final mode = (message['m'] as num?)?.toInt();
    if (mode == null || mode < 0 || mode > 0x1ff) {
      await _reply(hostError(id, 'That is not a permission value.'));
      return;
    }
    final result = await Process.run('chmod', [
      mode.toRadixString(8).padLeft(3, '0'),
      path,
    ]);
    if (result.exitCode != 0) {
      await _reply(hostError(id, 'The permissions could not be changed.'));
      return;
    }
    await _reply(hostOk(id));
  }

  Future<void> _opRead(int id, Map<String, dynamic> message) async {
    final path = await jail.resolve(_path(message, 'p'), mustExist: true);
    final file = File(path);
    if (!await file.exists()) {
      await _reply(hostError(id, 'That file is no longer there.'));
      return;
    }
    final offset = (message['o'] as num?)?.toInt() ?? 0;
    final total = await file.length();
    if (offset < 0 || offset > total) {
      await _reply(hostError(id, 'That file changed while it was being read.'));
      return;
    }

    await _reply(hostOk(id, {'s': total}));

    final stream = _ReadStream();
    _reads[id] = stream;
    unawaited(_pumpRead(id, file, offset, total, stream));
  }

  /// Streams a file out in [kHostChunkBytes] slices, stopping early if the
  /// client cancelled or the connection went away.
  Future<void> _pumpRead(
    int id,
    File file,
    int offset,
    int total,
    _ReadStream stream,
  ) async {
    RandomAccessFile? handle;
    try {
      handle = await file.open();
      await handle.setPosition(offset);
      var position = offset;
      while (position < total && !stream.cancelled && !_closed) {
        final take = (total - position) < kHostChunkBytes
            ? total - position
            : kHostChunkBytes;
        final bytes = await handle.read(take);
        if (bytes.isEmpty) break;
        await _sendSealed(encodeChunkFrame(id, bytes));
        position += bytes.length;
      }
      if (!stream.cancelled && !_closed) {
        await _reply(hostEvent(id, kEventEof));
      }
    } catch (e) {
      if (!_closed) {
        await _reply(hostEvent(id, kEventError, 'The file could not be read.'));
      }
      debugPrint('luma host: read failed: $e');
    } finally {
      await handle?.close();
      _reads.remove(id);
    }
  }

  Future<void> _opWriteOpen(int id, Map<String, dynamic> message) async {
    if (await _refuseWrite(id)) return;
    final path = await jail.resolve(_path(message, 'p'));
    final parent = File(path).parent;
    if (!await parent.exists()) {
      await _reply(hostError(id, 'The folder for that file is not there.'));
      return;
    }
    final handle = await File(path).open(mode: FileMode.writeOnly);
    _writes[id] = _WriteStream(handle: handle, path: path);
    await _reply(hostOk(id));
  }

  Future<void> _handleChunk(int id, Uint8List bytes) async {
    final stream = _writes[id];
    if (stream == null) {
      // Nothing is open under that id — a chunk after a failed open, or one
      // the client should not have sent. Dropping it is right; the close will
      // report the mismatch.
      return;
    }
    if (stream.error != null) return;
    try {
      await stream.handle.writeFrom(bytes);
      stream.written += bytes.length;
    } catch (e) {
      stream.error = 'The file could not be written: $e';
    }
  }

  Future<void> _opWriteClose(int id) async {
    final stream = _writes.remove(id);
    if (stream == null) {
      await _reply(hostError(id, 'That upload was not open.'));
      return;
    }
    try {
      await stream.handle.close();
    } catch (_) {
      // Already closed; the error below is the one worth reporting.
    }
    if (stream.error != null) {
      try {
        await File(stream.path).delete();
      } catch (_) {
        // A half-written file left behind would look like a finished upload.
      }
      await _reply(hostError(id, stream.error!));
      return;
    }
    // Not counted here: _serve already adds every received frame, chunks
    // included, so adding the file's size again would double it.
    await _reply(hostOk(id, {'n': stream.written}));
  }

  /// Answers a write op with a refusal when the host is read-only.
  Future<bool> _refuseWrite(int id) async {
    if (!_readOnly) return false;
    await _reply(hostError(
      id,
      'This device is sharing its folder read-only.',
    ));
    return true;
  }

  String _path(Map<String, dynamic> message, String key) {
    final value = message[key];
    if (value is! String || value.isEmpty) {
      throw const HostAccessDenied('That request had no path.');
    }
    return value;
  }

  static String _describeFileError(FileSystemException e) {
    final reason = e.osError?.message;
    return reason == null || reason.isEmpty
        ? 'That did not work.'
        : 'That did not work: $reason';
  }

  // ------------------------------------------------------------- transport

  Future<Map<String, dynamic>> _readPlainControl() async {
    final body = await _nextFrame();
    final frame = decodeFrame(body);
    if (!frame.isControl) {
      throw const HostProtocolException('Expected a handshake message.');
    }
    return frame.control!;
  }

  Future<Uint8List> _nextFrame() {
    if (_fatal != null) return Future.error(_fatal!);
    if (_frames.isNotEmpty) return Future.value(_frames.removeFirst());
    final completer = Completer<Uint8List>();
    _waiting = completer;
    return completer.future;
  }

  void _onData(Uint8List data) {
    try {
      for (final frame in _reader.add(data)) {
        final waiting = _waiting;
        if (waiting != null && !waiting.isCompleted) {
          _waiting = null;
          waiting.complete(frame);
        } else {
          _frames.add(frame);
        }
      }
    } catch (e) {
      _fail(e);
    }
  }

  void _fail(Object error) {
    _fatal ??= error;
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null && !waiting.isCompleted) waiting.completeError(error);
  }

  Future<void> _reply(Map<String, dynamic> message) =>
      _sendSealed(encodeControlFrame(message));

  Future<void> _sendSealed(Uint8List plain) async {
    final channel = _channel;
    if (channel == null || _closed) return;
    await _send(await channel.seal(plain));
  }

  /// Serialised so two frames never interleave on the wire and the nonce
  /// counter advances in the same order the bytes leave.
  Future<void> _send(Uint8List body) {
    final next = _sendChain.then((_) async {
      if (_closed) return;
      try {
        socket.add(frameBytes(body));
        client.bytesSent += body.length;
        // Waiting for the buffer to drain is what stops a download from
        // reading the whole file into memory when the network is slower than
        // the disk.
        await socket.flush();
      } catch (e) {
        _fail(e);
      }
    });
    _sendChain = next.catchError((_) {});
    return next;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    settleApproval(false);
    for (final stream in _reads.values) {
      stream.cancelled = true;
    }
    _reads.clear();
    for (final stream in _writes.values) {
      try {
        await stream.handle.close();
      } catch (_) {
        // Going away regardless.
      }
    }
    _writes.clear();
    _fail(const HostProtocolException('The connection closed.'));
    try {
      await socket.close();
    } catch (_) {
      // Already gone.
    }
    socket.destroy();
  }
}

class _ReadStream {
  bool cancelled = false;
}

class _WriteStream {
  _WriteStream({required this.handle, required this.path});

  final RandomAccessFile handle;
  final String path;
  int written = 0;
  String? error;
}

extension _FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
