import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../storage/storage_guard.dart';
import 'sftp_crypto.dart';
import 'sftp_site.dart';

/// Flat-file (JSON) store for the SFTP plugin's Site Manager.
///
/// Everything here stays on this device: the file sits in the app's support
/// directory and is never registered with a sync collection, so no server —
/// luma's included — ever sees a host, a username or a password. Secrets are
/// encrypted by [SftpSecretCrypto] before they are written, and only when the
/// site has "save password" ticked.
class SftpSiteStore extends ChangeNotifier {
  factory SftpSiteStore() => instance;

  static final SftpSiteStore instance = SftpSiteStore._();

  SftpSiteStore._() {
    _load();
  }

  static const _fileName = 'luma_sftp_sites.json';
  static const _secretField = 'secret';

  List<SftpSite> _sites = [];

  /// Saved sites, most recently used first.
  List<SftpSite> get sites => List.unmodifiable(_sites);

  bool _loaded = false;
  bool get loaded => _loaded;

  File? _file;
  SftpSecretCrypto? _crypto;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}${Platform.pathSeparator}$_fileName');
    return _file!;
  }

  Future<SftpSecretCrypto> _getCrypto() async =>
      _crypto ??= await SftpSecretCrypto.load();

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        final list = raw is Map<String, dynamic> ? raw['sites'] as List? : null;
        _sites = (list ?? const [])
            .map((e) => SftpSite.fromJson(e as Map<String, dynamic>))
            .toList();
        _sort();
      }
    } catch (_) {
      _sites = [];
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final file = await _getFile();
    await file.writeAsString(
      jsonEncode({'sites': _sites.map((s) => s.toJson()).toList()}),
      flush: true,
    );
    StorageGuard.instance.scheduleRefresh();
  }

  void _sort() {
    _sites.sort((a, b) {
      final aUsed = a.lastUsed;
      final bUsed = b.lastUsed;
      if (aUsed == null && bUsed == null) {
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      }
      if (aUsed == null) return 1;
      if (bUsed == null) return -1;
      return bUsed.compareTo(aUsed);
    });
  }

  SftpSite? siteById(String id) {
    for (final site in _sites) {
      if (site.id == id) return site;
    }
    return null;
  }

  /// Adds or replaces [site]. When [secret] is non-null and the site has
  /// [SftpSite.saveSecret] set, it is encrypted and stored; when the site has
  /// saving turned off, any previously remembered secret is dropped.
  Future<void> upsert(SftpSite site, {String? secret}) async {
    var next = site;
    if (!site.saveSecret) {
      next = site.copyWith(clearSecretToken: true);
    } else if (secret != null) {
      if (secret.isEmpty) {
        next = site.copyWith(clearSecretToken: true);
      } else {
        final crypto = await _getCrypto();
        next = site.copyWith(
          secretToken:
              crypto.encrypt(secret, siteId: site.id, field: _secretField),
        );
      }
    }

    final index = _sites.indexWhere((s) => s.id == next.id);
    if (index >= 0) {
      _sites[index] = next;
    } else {
      _sites.add(next);
    }
    _sort();
    notifyListeners();
    await _save();
  }

  Future<void> delete(String id) async {
    _sites.removeWhere((s) => s.id == id);
    notifyListeners();
    await _save();
  }

  /// Stamps [id] as just-used so the Site Manager keeps recent servers on top.
  Future<void> markUsed(String id) async {
    final index = _sites.indexWhere((s) => s.id == id);
    if (index < 0) return;
    _sites[index] = _sites[index].copyWith(lastUsed: DateTime.now());
    _sort();
    notifyListeners();
    await _save();
  }

  /// Remembers where a site was last browsing, so reconnecting lands back in
  /// the same folders instead of at the top.
  Future<void> rememberDirectories(
    String id, {
    String? remote,
    String? local,
  }) async {
    final index = _sites.indexWhere((s) => s.id == id);
    if (index < 0) return;
    final current = _sites[index];
    if (current.remoteDirectory == (remote ?? current.remoteDirectory) &&
        current.localDirectory == (local ?? current.localDirectory)) {
      return;
    }
    _sites[index] = current.copyWith(
      remoteDirectory: remote,
      localDirectory: local,
    );
    notifyListeners();
    await _save();
  }

  /// The remembered password or key passphrase for [site], or null when
  /// nothing is saved (or the token no longer decrypts, e.g. the key file was
  /// replaced — in which case the user is asked again rather than being
  /// handed an empty password).
  Future<String?> secretFor(SftpSite site) async {
    final token = site.secretToken;
    if (!site.saveSecret || token == null || token.isEmpty) return null;
    final crypto = await _getCrypto();
    return crypto.decrypt(token, siteId: site.id, field: _secretField);
  }
}
