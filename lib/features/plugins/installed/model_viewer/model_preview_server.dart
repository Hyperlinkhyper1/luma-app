import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/current_l.dart';
import 'model_viewer_repository.dart';

/// Serves the bundled viewer and the selected model on a short-lived URL.
/// Repository files are always served as data. GitHub credentials stay in Dart.
class ModelPreviewServer {
  ModelPreviewServer._(
    this._server,
    this._prefix,
    this._catalogue,
    this._model,
  );

  static const _assets = 'assets/model_viewer';
  static const _dependentExtensions = {
    'bin',
    'mtl',
    'png',
    'jpg',
    'jpeg',
    'webp',
    'avif',
    'gif',
    'bmp',
    'tga',
  };
  static const _previewByteBudget = 256 * 1024 * 1024;
  static final _vendorSegment = RegExp(r'^[A-Za-z0-9._-]+$');

  final HttpServer _server;
  final String _prefix;
  final ModelCatalogue _catalogue;
  final RepositoryModel _model;
  final _requestedFiles = <String>{};
  final _pending = <String, Future<Uint8List>>{};
  final _closed = Completer<void>();
  int _requestedBytes = 0;

  static Future<ModelPreviewServer> start(
    ModelCatalogue catalogue,
    RepositoryModel model,
    L t,
  ) async {
    final random = Random.secure();
    final prefix = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final preview = ModelPreviewServer._(server, prefix, catalogue, model);
    final config = jsonEncode({
      'format': model.format.name,
      'file': [
        'files',
        ...model.path.split('/'),
      ].map(Uri.encodeComponent).join('/'),
      'loading': t.modelViewerLoadingModel,
      'error': t.modelViewerPreviewFailed,
      'missing': t.modelViewerMissingResources,
      'reset': t.modelViewerResetCamera,
      'play': t.modelViewerPlayAnimation,
      'pause': t.modelViewerPauseAnimation,
    });
    server.listen((request) => unawaited(preview._serve(request, config)));
    return preview;
  }

  Uri get url => Uri(
    scheme: 'http',
    host: '127.0.0.1',
    port: _server.port,
    path: '/$_prefix/',
  );

  Future<void> close() async {
    if (_closed.isCompleted) return;
    _closed.complete();
    await _server.close(force: true);
  }

  Future<void> _serve(HttpRequest request, String config) async {
    final response = request.response;
    final segments = request.uri.pathSegments;
    final fetchSite = request.headers.value('sec-fetch-site');
    final host = request.headers.value(HttpHeaders.hostHeader);
    response.headers
      ..set('Cache-Control', 'no-store')
      ..set('Referrer-Policy', 'no-referrer')
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Cross-Origin-Resource-Policy', 'same-origin')
      ..set(
        'Content-Security-Policy',
        "default-src 'none'; script-src 'self' 'wasm-unsafe-eval'; "
            "style-src 'self'; connect-src 'self' data: blob:; "
            "img-src 'self' data: blob:; worker-src blob:; "
            "base-uri 'none'; frame-ancestors 'none'; form-action 'none'",
      );
    try {
      if (host != url.authority ||
          request.method != 'GET' ||
          (fetchSite != null &&
              fetchSite != 'same-origin' &&
              fetchSite != 'none') ||
          segments.firstOrNull != _prefix) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final path = segments.skip(1).toList();
      if (path.isEmpty || (path.length == 1 && path.single.isEmpty)) {
        await _asset(response, 'index.html', ContentType.html);
      } else if (path.length == 1 && path.single == 'config.json') {
        response.headers.contentType = ContentType.json;
        response.write(config);
      } else if (path.length == 1 && path.single == 'viewer.css') {
        await _asset(response, path.single, ContentType('text', 'css'));
      } else if (path.length == 1 && path.single == 'viewer.js') {
        await _asset(response, path.single, ContentType('text', 'javascript'));
      } else if (path.first == 'vendor' &&
          path.every(
            (part) =>
                _vendorSegment.hasMatch(part) && part != '.' && part != '..',
          )) {
        final name = path.join('/');
        final type = switch (fileExtension(name)) {
          'js' => ContentType('text', 'javascript'),
          'wasm' => ContentType('application', 'wasm'),
          _ => ContentType.binary,
        };
        await _asset(response, name, type);
      } else if (path.first == 'files') {
        await _file(response, path.skip(1).join('/'));
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } on ModelViewerException catch (error) {
      if (_closed.isCompleted) return;
      response.statusCode = HttpStatus.unprocessableEntity;
      response.headers.contentType = ContentType.text;
      response.write(error.message);
    } catch (_) {
      if (!_closed.isCompleted) response.statusCode = HttpStatus.badGateway;
    } finally {
      try {
        await response.close();
      } on IOException {
        // The user can close a preview while its requests are in flight.
      }
    }
  }

  Future<void> _asset(
    HttpResponse response,
    String name,
    ContentType type,
  ) async {
    final data = await rootBundle.load('$_assets/$name');
    response.headers.contentType = type;
    response.add(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  Future<void> _file(HttpResponse response, String path) async {
    final size = _catalogue.sizeOf(path);
    if (size == null ||
        (path != _model.path &&
            !_dependentExtensions.contains(fileExtension(path)))) {
      response.statusCode = HttpStatus.notFound;
      return;
    }
    if (size > ModelViewerRepository.maxFileBytes ||
        (!_requestedFiles.contains(path) &&
            _requestedBytes + size > _previewByteBudget)) {
      throw ModelViewerException(currentL.modelViewerAssetTooLarge);
    }
    if (_requestedFiles.add(path)) _requestedBytes += size;
    final data = await (_pending[path] ??= _catalogue
        .read(path, abort: _closed.future)
        .whenComplete(() {
          _pending.remove(path);
        }));
    if (_closed.isCompleted) return;
    response.headers.contentType = ContentType.binary;
    response.add(data);
  }
}
