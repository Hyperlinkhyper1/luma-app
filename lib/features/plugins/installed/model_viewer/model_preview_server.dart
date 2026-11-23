import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

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
    this._files,
    this._onThumbnail,
  );

  static const _assets = 'assets/model_viewer';
  static const thumbnailSize = (width: 288, height: 176);
  static const thumbnailFileBudget = 24 * 1024 * 1024;
  static const _thumbnailImageBudget = 256 * 1024;
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
  final List<_PreviewFiles> _files;
  final void Function(RepositoryModel, Uint8List?)? _onThumbnail;
  final _closed = Completer<void>();
  int _thumbnailIndex = 0;

  static Future<ModelPreviewServer> start(
    ModelCatalogue catalogue,
    RepositoryModel model,
    L t,
  ) => _start(catalogue, [model], t);

  static Future<ModelPreviewServer> startThumbnails(
    ModelCatalogue catalogue,
    List<RepositoryModel> models,
    L t,
    void Function(RepositoryModel, Uint8List?) onThumbnail,
  ) => _start(catalogue, models, t, onThumbnail: onThumbnail);

  static Future<ModelPreviewServer> _start(
    ModelCatalogue catalogue,
    List<RepositoryModel> models,
    L t, {
    void Function(RepositoryModel, Uint8List?)? onThumbnail,
  }) async {
    final random = Random.secure();
    final prefix = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final preview = ModelPreviewServer._(
      server,
      prefix,
      catalogue,
      models.map(_PreviewFiles.new).toList(),
      onThumbnail,
    );
    final config = jsonEncode({
      if (onThumbnail == null)
        ..._modelConfig(models.single, ['files'])
      else ...{
        'width': thumbnailSize.width,
        'height': thumbnailSize.height,
        'thumbnails': [
          for (var index = 0; index < models.length; index++)
            {
              ..._modelConfig(models[index], ['tiles', '$index', 'files']),
              'result': 'tiles/$index/image',
            },
        ],
      },
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

  static Map<String, String> _modelConfig(
    RepositoryModel model,
    List<String> filePrefix,
  ) => {
    'format': model.format.name,
    'file': [
      ...filePrefix,
      ...model.path.split('/'),
    ].map(Uri.encodeComponent).join('/'),
  };

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
          (fetchSite != null &&
              fetchSite != 'same-origin' &&
              fetchSite != 'none') ||
          segments.firstOrNull != _prefix) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final path = segments.skip(1).toList();
      if (_onThumbnail != null && path.firstOrNull == 'tiles') {
        await _serveThumbnail(request, path);
      } else if (request.method != 'GET') {
        response.statusCode = HttpStatus.notFound;
      } else if (path.isEmpty || (path.length == 1 && path.single.isEmpty)) {
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
      } else if (path.first == 'files' && _onThumbnail == null) {
        await _file(response, _files.single, path.skip(1).join('/'));
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

  Future<void> _serveThumbnail(HttpRequest request, List<String> path) async {
    final response = request.response;
    final index = _thumbnailIndex;
    if (path.length < 3 || index >= _files.length || path[1] != '$index') {
      response.statusCode = HttpStatus.notFound;
      return;
    }
    final files = _files[index];
    if (request.method == 'GET' && path[2] == 'files') {
      await _file(response, files, path.skip(3).join('/'));
      return;
    }
    if (request.method != 'POST' || path.length != 3 || path[2] != 'image') {
      response.statusCode = HttpStatus.notFound;
      return;
    }
    final image = BytesBuilder(copy: false);
    await for (final chunk in request) {
      if (image.length + chunk.length > _thumbnailImageBudget) {
        response.statusCode = HttpStatus.requestEntityTooLarge;
        return;
      }
      image.add(chunk);
    }
    if (_closed.isCompleted || index != _thumbnailIndex) {
      response.statusCode = HttpStatus.notFound;
      return;
    }
    _thumbnailIndex++;
    response.statusCode = HttpStatus.noContent;
    _onThumbnail!(files.model, image.isEmpty ? null : image.takeBytes());
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

  Future<void> _file(
    HttpResponse response,
    _PreviewFiles files,
    String path,
  ) async {
    final thumbnail = _onThumbnail != null;
    final size = _catalogue.sizeOf(path);
    if (size == null ||
        (path != files.model.path &&
            !(thumbnail
                ? fileExtension(path) == 'bin'
                : _dependentExtensions.contains(fileExtension(path))))) {
      response.statusCode = HttpStatus.notFound;
      return;
    }
    final byteBudget = thumbnail ? thumbnailFileBudget : _previewByteBudget;
    if (size > ModelViewerRepository.maxFileBytes ||
        (!files.requested.contains(path) && files.bytes + size > byteBudget)) {
      throw ModelViewerException(currentL.modelViewerAssetTooLarge);
    }
    if (files.requested.add(path)) files.bytes += size;
    final data = await (files.pending[path] ??= _catalogue
        .read(path, abort: _closed.future)
        .whenComplete(() {
          files.pending.remove(path);
        }));
    if (_closed.isCompleted) return;
    response.headers.contentType = ContentType.binary;
    response.add(data);
  }
}

class _PreviewFiles {
  _PreviewFiles(this.model);

  final RepositoryModel model;
  final requested = <String>{};
  final pending = <String, Future<Uint8List>>{};
  int bytes = 0;
}
