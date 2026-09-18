import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'home_layout.dart';

class HomeRepository extends ChangeNotifier {
  HomeRepository({String? family, Future<File> Function()? file})
    : family = family ?? deviceFamily,
      _fileProvider = file {
    if (this.family != 'desktop' && this.family != 'phone') {
      throw ArgumentError.value(this.family, 'family');
    }
    _layout = HomeLayout.defaults(this.family);
    ready = _load();
  }

  static String get deviceFamily =>
      defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS
      ? 'phone'
      : 'desktop';

  final String family;
  String get collectionId => 'home_$family';
  final Future<File> Function()? _fileProvider;
  late HomeLayout _layout;
  HomeLayout get layout => _layout;
  late final Future<void> ready;
  Future<void> _writing = Future.value();
  File? _file;
  bool _disposed = false;
  String? loadError;

  Future<File> _getFile() async => _file ??= _fileProvider != null
      ? await _fileProvider()
      : File(
          '${(await getApplicationSupportDirectory()).path}/luma_home_$family.json',
        );

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        _layout = _decode(jsonDecode(await file.readAsString()));
      }
    } catch (e) {
      loadError = 'Your saved layout could not be loaded. $e';
    }
    if (!_disposed) notifyListeners();
  }

  HomeLayout _decode(Object? raw) {
    if (raw is! Map || raw['version'] != 1 || raw['family'] != family) {
      throw const FormatException(
        'This home layout belongs to a different device format.',
      );
    }
    return HomeLayout.fromJson(
      raw['layout'],
      columns: family == 'phone' ? 4 : 12,
    );
  }

  Map<String, dynamic> _snapshot(HomeLayout value) => {
    'version': 1,
    'family': family,
    'layout': value.toJson(),
  };

  Future<Object?> exportData() async {
    await ready;
    if (loadError != null) throw StateError(loadError!);
    return _snapshot(_layout);
  }

  Future<void> importData(Object? raw) async {
    await ready;
    await save(_decode(raw));
  }

  Future<void> save(HomeLayout value) async {
    await ready;
    final valid = HomeLayout.fromJson(
      value.toJson(),
      columns: family == 'phone' ? 4 : 12,
    );
    final operation = _writing.then((_) async {
      final file = await _getFile();
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(jsonEncode(_snapshot(valid)), flush: true);
      await temporary.rename(file.path);
      _layout = valid;
      loadError = null;
      if (!_disposed) notifyListeners();
    });
    _writing = operation.catchError((Object _) {});
    await operation;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
