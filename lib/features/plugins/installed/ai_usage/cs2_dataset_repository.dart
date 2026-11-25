import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cs2_dataset/cs2_dataset.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../sync/server_access.dart';
import '../../../../sync/sync_service.dart';

class Cs2DatasetRepository {
  Cs2DatasetRepository._(
    this._sync,
    this._account,
    this._privateFile,
    this._downloadFile,
  );

  static Future<Cs2DatasetRepository> open(SyncService? sync) async {
    final account = identity(sync);
    final directory = await getApplicationSupportDirectory();
    final profile = sha256.convert(utf8.encode(account)).toString();
    final root = Directory(p.join(directory.path, 'cs2-datasets', profile));
    root.createSync(recursive: true);
    return Cs2DatasetRepository._(
      sync,
      account,
      File(p.join(root.path, 'private.json')),
      File(p.join(root.path, 'download.json')),
    ).._load();
  }

  static String identity(SyncService? sync) => sync?.email == null
      ? 'local'
      : '${sync?.serverUrl}|${sync?.email?.toLowerCase()}';

  final SyncService? _sync;
  final String _account;
  final File _privateFile;
  final File _downloadFile;
  var personal = Cs2Dataset.empty();
  Cs2Dataset? downloaded;
  var _replays = <String>{};

  bool get online => _sync?.serverReady == true;

  void _load() {
    _readPrivate();
    if (_downloadFile.existsSync()) {
      downloaded = Cs2Dataset.fromJson(
        _decode(_downloadFile.readAsStringSync()),
      );
    }
  }

  void _readPrivate() {
    if (!_privateFile.existsSync()) return;
    final json = _decode(_privateFile.readAsStringSync());
    personal = Cs2Dataset.fromJson(json['dataset'] as Map<String, dynamic>);
    _replays = (json['replays'] as List).cast<String>().toSet();
  }

  /// Returns false if this replay has already been saved on the device.
  bool save(Cs2MatchInput input) {
    _readPrivate();
    final digest = input.digest;
    if (digest != null && _replays.contains(digest)) return false;
    final updated = Cs2Dataset.fromJson(personal.toJson())..add(input.match);
    final replays = {..._replays, ?digest};
    _write(
      _privateFile,
      jsonEncode({'dataset': updated.toJson(), 'replays': replays.toList()}),
    );
    personal = updated;
    _replays = replays;
    return true;
  }

  Future<({bool canDownload, Map<String, int> maps})> catalog() async {
    final data = await _get('');
    return (
      canDownload: data['canDownload'] == true,
      maps: {
        for (final map in (data['maps'] as List).cast<Map<String, dynamic>>())
          map['id'] as String: map['rounds'] as int,
      },
    );
  }

  Future<Cs2Prediction> prediction(String map, Cs2Outcome? previous) async {
    final data = await _get('/prediction', {
      'map': map,
      if (previous != null) 'previous': previous.name,
    });
    final counts = (data['counts'] as List).cast<int>();
    if (counts.length != 3 || counts.any((count) => count < 0)) {
      throw const FormatException('Invalid CS2 prediction.');
    }
    return Cs2Prediction(counts, conditioned: data['conditioned'] == true);
  }

  Future<void> download() async {
    final data = await _get('/download');
    final compiled = Cs2Dataset.fromJson(data);
    final json = jsonEncode(compiled.toJson());
    _write(_downloadFile, json);
    downloaded = compiled;
  }

  Uint8List downloadedBytes() => _downloadFile.readAsBytesSync();

  Future<Cs2MatchInput> importReplay({
    required String name,
    required int size,
    required Stream<List<int>> data,
  }) async {
    final request =
        http.StreamedRequest('POST', _uri('/replay', {'name': name}))
          ..headers.addAll(_headers)
          ..headers['Content-Type'] = 'application/octet-stream'
          ..contentLength = size;
    final client = GatedServerClient();
    try {
      final response = client.send(request).then(http.Response.fromStream);
      final upload = request.sink
          .addStream(data)
          .whenComplete(request.sink.close);
      final results = await Future.wait<Object?>([
        response,
        upload,
      ], eagerError: true).timeout(const Duration(minutes: 3));
      final body = _readResponse(results.first! as http.Response);
      return Cs2MatchInput(
        Cs2Match.fromJson(body),
        digest: body['digest'] as String,
      );
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    final client = GatedServerClient();
    try {
      final response = await client
          .get(_uri(path, query), headers: _headers)
          .timeout(const Duration(seconds: 15));
      return _readResponse(response);
    } finally {
      client.close();
    }
  }

  Uri _uri(String path, Map<String, String>? query) {
    if (!online || identity(_sync) != _account) {
      throw const ServerAccessDeniedException();
    }
    final server = _sync!.serverUrl!.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse(
      '$server/api/v1/datasets/cs2$path',
    ).replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${_sync!.authToken}',
  };

  static Map<String, dynamic> _readResponse(http.Response response) {
    if (response.statusCode != 200) {
      try {
        final message = _decode(utf8.decode(response.bodyBytes))['message'];
        if (message is String) throw Cs2DatasetRequestException(message);
      } on FormatException {
        // A proxy can answer with its own error page.
      } on TypeError {
        // A response without a JSON object has no server error message.
      }
      throw Cs2DatasetRequestException(
        'The server returned HTTP ${response.statusCode}.',
      );
    }
    return _decode(utf8.decode(response.bodyBytes));
  }

  static Map<String, dynamic> _decode(String json) =>
      jsonDecode(json) as Map<String, dynamic>;

  static void _write(File file, String json) {
    final temp = File('${file.path}.tmp');
    temp.writeAsStringSync(json, flush: true);
    temp.renameSync(file.path);
  }
}

class Cs2MatchInput {
  const Cs2MatchInput(this.match, {this.digest});

  final Cs2Match match;
  final String? digest;
}

class Cs2DatasetRequestException implements Exception {
  const Cs2DatasetRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}
