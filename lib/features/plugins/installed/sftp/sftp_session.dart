import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import 'sftp_known_hosts.dart';
import 'sftp_paths.dart';
import 'sftp_site.dart';

/// One entry in the remote pane.
class SftpEntry {
  const SftpEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.isLink = false,
    this.size = 0,
    this.modified,
    this.mode,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final bool isLink;
  final int size;
  final DateTime? modified;

  /// POSIX permission bits, or null when the server didn't send them.
  final int? mode;

  String get permissionsLabel => formatPermissions(mode);
}

/// Anything that went wrong talking to a server, phrased for a person rather
/// than for a log file.
class SftpConnectionException implements Exception {
  SftpConnectionException(this.message, {this.isAuthFailure = false});

  final String message;

  /// True when the server rejected the credentials, so the UI can reopen the
  /// password prompt instead of sending the user back to the Site Manager.
  final bool isAuthFailure;

  @override
  String toString() => message;
}

/// Raised when the user declines a host key, or when a trusted key changed.
class SftpHostKeyRejected extends SftpConnectionException {
  SftpHostKeyRejected(super.message);
}

/// What a caller must decide before a connection continues: this server's key
/// is new, or no longer the one that was trusted.
class SftpHostKeyPrompt {
  const SftpHostKeyPrompt({
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    required this.changed,
    this.previousFingerprint,
  });

  final String host;
  final int port;
  final String keyType;
  final String fingerprint;

  /// True when a *different* key was trusted for this host before.
  final bool changed;
  final String? previousFingerprint;
}

/// Cooperative cancellation for a single transfer. The queue hands one to
/// each running item and flips it when the user hits stop; the transfer loops
/// check it between chunks and an in-flight upload is aborted outright.
class TransferCancelToken {
  bool _cancelled = false;
  void Function()? _onCancel;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel?.call();
  }

  /// Registers the abort hook for whatever is currently in flight.
  void attach(void Function()? onCancel) => _onCancel = onCancel;
}

/// Thrown inside a transfer when its token was cancelled, so the queue can
/// tell "the user stopped it" apart from a genuine failure.
class TransferCancelled implements Exception {
  const TransferCancelled();

  @override
  String toString() => 'Transfer cancelled';
}

/// The slice of a connection the transfer queue needs. Keeping it separate
/// from [SftpSession] lets the queue's behaviour — ordering, concurrency,
/// cancellation, retries — be tested without a server.
abstract class TransferBackend {
  Future<void> upload(
    File source,
    String remotePath, {
    void Function(int bytes)? onProgress,
    TransferCancelToken? cancelToken,
  });

  Future<void> download(
    String remotePath,
    File destination, {
    void Function(int bytes)? onProgress,
    TransferCancelToken? cancelToken,
  });

  Future<void> makeDirectories(String path);
}

/// A live connection to one server: the SSH transport, the SFTP channel on
/// top of it, and every file operation the panes and the queue perform.
///
/// The socket is opened straight from this device to the address the user
/// typed. None of this is luma-server traffic, so none of it goes through
/// `GatedServerClient` — and no host, credential or byte of a transfer ever
/// reaches a luma server.
class SftpSession implements TransferBackend {
  SftpSession._(this._client, this._sftp, this.site, this.homeDirectory);

  final SSHClient _client;
  final SftpClient _sftp;
  final SftpSite site;

  /// Where the server put us on login — the "home" button's target.
  final String homeDirectory;

  bool get isClosed => _client.isClosed;

  /// Completes when the transport goes away, whether we closed it or the
  /// server dropped us.
  Future<void> get done => _client.done;

  /// Opens a connection for [site].
  ///
  /// [secret] is the password, or the private key's passphrase when the site
  /// authenticates with a key. [onHostKey] is asked whenever the server's key
  /// is unknown or has changed; returning false aborts the connection before
  /// any credential is sent.
  static Future<SftpSession> connect({
    required SftpSite site,
    String? secret,
    required Future<bool> Function(SftpHostKeyPrompt prompt) onHostKey,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final host = site.host.trim();
    if (host.isEmpty) {
      throw SftpConnectionException('This site has no host name.');
    }

    List<SSHKeyPair>? identities;
    if (site.authMode == SftpAuthMode.key) {
      identities = await _loadIdentities(site, secret);
    }

    final SSHSocket socket;
    try {
      socket = await SSHSocket.connect(host, site.port, timeout: timeout);
    } on SocketException catch (e) {
      throw SftpConnectionException(
        'Could not reach $host on port ${site.port}.\n'
        '${e.osError?.message ?? e.message}',
      );
    } on TimeoutException {
      throw SftpConnectionException(
        'Timed out connecting to $host on port ${site.port}.',
      );
    }

    var hostKeyRejected = false;
    final client = SSHClient(
      socket,
      username: site.username.trim(),
      identities: identities,
      onPasswordRequest:
          site.authMode == SftpAuthMode.password ? () => secret ?? '' : null,
      onVerifyHostKey: (type, fingerprint) async {
        final printable = utf8.decode(fingerprint, allowMalformed: true);
        final verdict =
            await SftpKnownHosts.instance.check(host, site.port, type, printable);
        if (verdict == KnownHostVerdict.trusted) return true;
        final previous = verdict == KnownHostVerdict.mismatch
            ? await SftpKnownHosts.instance.trustedFingerprint(host, site.port)
            : null;
        final accepted = await onHostKey(
          SftpHostKeyPrompt(
            host: host,
            port: site.port,
            keyType: type,
            fingerprint: printable,
            changed: verdict == KnownHostVerdict.mismatch,
            previousFingerprint: previous,
          ),
        );
        if (!accepted) {
          hostKeyRejected = true;
          return false;
        }
        await SftpKnownHosts.instance.trust(host, site.port, type, printable);
        return true;
      },
    );

    try {
      await client.authenticated;
    } catch (e) {
      client.close();
      if (hostKeyRejected) {
        throw SftpHostKeyRejected(
          "The server's key was not accepted, so nothing was sent to it.",
        );
      }
      throw SftpConnectionException(
        _describeAuthError(e, site),
        isAuthFailure: e is SSHAuthFailError || e is SSHAuthAbortError,
      );
    }

    final SftpClient sftp;
    try {
      sftp = await client.sftp();
    } catch (e) {
      client.close();
      throw SftpConnectionException(
        'Signed in, but the server would not open an SFTP channel. Its SSH '
        'service may have the SFTP subsystem disabled.\n($e)',
      );
    }

    var home = RemotePath.separator;
    try {
      home = RemotePath.normalize(await sftp.absolute('.'));
    } catch (_) {
      // Some servers refuse realpath; the root is a safe landing spot.
    }

    return SftpSession._(client, sftp, site, home);
  }

  static Future<List<SSHKeyPair>> _loadIdentities(
    SftpSite site,
    String? passphrase,
  ) async {
    final path = site.keyPath?.trim();
    if (path == null || path.isEmpty) {
      throw SftpConnectionException(
        'This site is set to key authentication but no key file is chosen.',
      );
    }
    final file = File(path);
    if (!await file.exists()) {
      throw SftpConnectionException('Private key not found at $path');
    }

    final String pem;
    try {
      pem = await file.readAsString();
    } catch (e) {
      throw SftpConnectionException('Could not read the private key.\n($e)');
    }

    final encrypted = SSHKeyPair.isEncryptedPem(pem);
    if (encrypted && (passphrase == null || passphrase.isEmpty)) {
      throw SftpConnectionException(
        'This private key is passphrase-protected.',
        isAuthFailure: true,
      );
    }

    try {
      return SSHKeyPair.fromPem(pem, encrypted ? passphrase : null);
    } catch (e) {
      throw SftpConnectionException(
        encrypted
            ? 'That passphrase does not unlock the private key.'
            : 'That file is not a private key luma can read.\n($e)',
        isAuthFailure: encrypted,
      );
    }
  }

  static String _describeAuthError(Object error, SftpSite site) {
    if (error is SSHAuthFailError) {
      return site.authMode == SftpAuthMode.key
          ? 'The server rejected that key for ${site.username}.'
          : 'The server rejected that username or password.';
    }
    if (error is SSHAuthAbortError) {
      return 'The server closed the connection during sign-in.\n'
          '${error.message}';
    }
    return 'Could not sign in to ${site.host}.\n$error';
  }

  /// Lists [path], directories first then files, each A to Z. '.' and '..'
  /// are dropped — the panes navigate with their own up button.
  Future<List<SftpEntry>> list(String path) async {
    final normalized = RemotePath.normalize(path);
    final names = await _sftp.listdir(normalized);
    final entries = <SftpEntry>[];
    for (final name in names) {
      if (name.filename == '.' || name.filename == '..') continue;
      entries.add(_toEntry(name.filename, normalized, name.attr));
    }
    entries.sort(compareEntries);
    return entries;
  }

  SftpEntry _toEntry(String filename, String directory, SftpFileAttrs attr) {
    final modifyTime = attr.modifyTime;
    final mode = attr.mode?.value;
    return SftpEntry(
      name: filename,
      path: RemotePath.join(directory, filename),
      isDirectory: attr.isDirectory,
      isLink: attr.isSymbolicLink,
      size: attr.size ?? 0,
      modified: modifyTime == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(modifyTime * 1000),
      mode: mode == null ? null : mode & 0x1ff,
    );
  }

  /// Directories first, then files, each alphabetical and case-insensitive —
  /// the order both panes list in.
  static int compareEntries(SftpEntry a, SftpEntry b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  /// Resolves what [path] actually is, following symlinks — so opening a
  /// linked directory behaves like opening the directory.
  Future<SftpEntry> statEntry(String path) async {
    final normalized = RemotePath.normalize(path);
    final attr = await _sftp.stat(normalized);
    return _toEntry(
      RemotePath.basename(normalized),
      RemotePath.parent(normalized),
      attr,
    );
  }

  Future<void> makeDirectory(String path) =>
      _sftp.mkdir(RemotePath.normalize(path));

  Future<void> rename(String from, String to) =>
      _sftp.rename(RemotePath.normalize(from), RemotePath.normalize(to));

  Future<void> removeFile(String path) =>
      _sftp.remove(RemotePath.normalize(path));

  /// Deletes a directory, emptying it first — SFTP's rmdir only removes empty
  /// ones, so a recursive delete has to walk the tree itself.
  Future<void> removeDirectory(String path) async {
    final normalized = RemotePath.normalize(path);
    for (final entry in await list(normalized)) {
      if (entry.isDirectory && !entry.isLink) {
        await removeDirectory(entry.path);
      } else {
        await _sftp.remove(entry.path);
      }
    }
    await _sftp.rmdir(normalized);
  }

  Future<void> chmod(String path, int mode) => _sftp.setStat(
        RemotePath.normalize(path),
        SftpFileAttrs(mode: SftpFileMode.value(mode)),
      );

  /// Creates [path] and every missing directory above it. Existing levels are
  /// left alone, so this is safe to call once per file in a folder upload.
  @override
  Future<void> makeDirectories(String path) async {
    final normalized = RemotePath.normalize(path);
    if (normalized == RemotePath.separator) return;
    final segments =
        normalized.split(RemotePath.separator).where((s) => s.isNotEmpty);
    var walked = '';
    for (final segment in segments) {
      walked = '$walked${RemotePath.separator}$segment';
      var exists = false;
      try {
        exists = (await _sftp.stat(walked)).isDirectory;
      } catch (_) {
        exists = false;
      }
      if (!exists) await _sftp.mkdir(walked);
    }
  }

  /// Every file under [path], flattened, each with its path relative to
  /// [path] — what a recursive download expands a folder into.
  Future<List<({SftpEntry entry, String relativePath})>> walk(
    String path,
  ) async {
    final results = <({SftpEntry entry, String relativePath})>[];

    Future<void> descend(String directory, String prefix) async {
      for (final entry in await list(directory)) {
        final relative =
            prefix.isEmpty ? entry.name : '$prefix${RemotePath.separator}${entry.name}';
        if (entry.isDirectory && !entry.isLink) {
          await descend(entry.path, relative);
        } else {
          results.add((entry: entry, relativePath: relative));
        }
      }
    }

    await descend(RemotePath.normalize(path), '');
    return results;
  }

  /// Streams [remotePath] into [destination]. [onProgress] receives the byte
  /// count written so far.
  @override
  Future<void> download(
    String remotePath,
    File destination, {
    void Function(int bytes)? onProgress,
    TransferCancelToken? cancelToken,
  }) async {
    final parent = destination.parent;
    if (!await parent.exists()) await parent.create(recursive: true);

    final remote = await _sftp.open(
      RemotePath.normalize(remotePath),
      mode: SftpFileOpenMode.read,
    );
    final sink = destination.openWrite();
    var written = 0;
    var cancelled = false;
    try {
      await for (final chunk in remote.read()) {
        if (cancelToken?.isCancelled ?? false) {
          cancelled = true;
          break;
        }
        sink.add(chunk);
        written += chunk.length;
        onProgress?.call(written);
      }
      await sink.flush();
    } finally {
      await sink.close();
      await remote.close();
      if (cancelled) {
        // A half-written file is worse than none: the pane would show it at
        // the wrong size and it would look like it transferred.
        try {
          if (await destination.exists()) await destination.delete();
        } catch (_) {}
      }
    }
    if (cancelled) throw const TransferCancelled();
  }

  /// Streams [source] up to [remotePath], creating it and truncating anything
  /// already there — which is what dropping a file onto a folder means.
  @override
  Future<void> upload(
    File source,
    String remotePath, {
    void Function(int bytes)? onProgress,
    TransferCancelToken? cancelToken,
  }) async {
    final normalized = RemotePath.normalize(remotePath);
    final remote = await _sftp.open(
      normalized,
      mode: SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    try {
      final writer = remote.write(
        source.openRead().map(Uint8List.fromList),
        onProgress: onProgress,
      );
      cancelToken?.attach(writer.abort);
      await writer.done;
      if (cancelToken?.isCancelled ?? false) throw const TransferCancelled();
    } finally {
      cancelToken?.attach(null);
      await remote.close();
      if (cancelToken?.isCancelled ?? false) {
        try {
          await _sftp.remove(normalized);
        } catch (_) {}
      }
    }
  }

  void close() {
    _sftp.close();
    _client.close();
  }
}
