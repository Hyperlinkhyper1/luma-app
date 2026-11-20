import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/model_viewer/model_preview_server.dart';
import 'package:luma/features/plugins/installed/model_viewer/model_viewer_page.dart';
import 'package:luma/features/plugins/installed/model_viewer/model_viewer_repository.dart';
import 'package:luma/features/plugins/installed/model_viewer/model_viewer_scope.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/l10n/current_l.dart';
import 'package:luma/security/secure_secret_store.dart';
import 'package:luma/theme/luma_theme.dart';

const _treeSha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _objSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _textureSha = 'cccccccccccccccccccccccccccccccccccccccc';
const _folderSha = 'dddddddddddddddddddddddddddddddddddddddd';
const _modelPath = 'models/cat #1.OBJ';
const _obj = 'v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n';

class _MemorySecrets extends SecureSecretStore {
  String? value;

  @override
  Future<String?> read(String name) async => value;

  @override
  Future<void> write(String name, String data) async => value = data;

  @override
  Future<void> delete(String name) async => value = null;
}

class _LoopbackHttp extends HttpOverrides {}

http.Response _json(Object body) => http.Response(jsonEncode(body), 200);

Map<String, dynamic> _blob(String path, String sha, int size) => {
  'path': path,
  'mode': '100644',
  'type': 'blob',
  'sha': sha,
  'size': size,
};

http.Response _repositoryResponse(http.Request request) {
  final path = request.url.pathSegments;
  expect(request.url.host, 'api.github.com');
  if (path.length == 3) return _json({'default_branch': 'main'});
  if (path[3] == 'commits') {
    return _json({
      'commit': {
        'tree': {'sha': _treeSha},
      },
    });
  }
  if (path[4] == 'trees') {
    return _json({
      'truncated': false,
      'tree': [
        _blob(_modelPath, _objSha, _obj.length),
        _blob('models/cat.png', _textureSha, 3),
        _blob('other.glb', _textureSha, 3),
        _blob('readme.txt', _textureSha, 3),
        {..._blob('link.stl', _textureSha, 3), 'mode': '120000'},
      ],
    });
  }
  expect(request.headers['Accept'], 'application/vnd.github.raw+json');
  return http.Response(path.last == _objSha ? _obj : 'abc', 200);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads and filters the catalogue at phone width', (tester) async {
    final repository = ModelViewerRepository(
      client: MockClient((request) async => _repositoryResponse(request)),
      secrets: _MemorySecrets(),
    );
    addTearDown(repository.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: LumaTheme.dark,
        home: ModelViewerScope(
          repository: repository,
          child: const ModelViewerPage(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'owner/repo');
    await tester.tap(find.text('Load models'));
    await tester.pumpAndSettle();
    expect(find.text('cat #1.OBJ'), findsOneWidget);
    expect(find.text('other.glb'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'models/');
    await tester.pumpAndSettle();
    expect(find.text('cat #1.OBJ'), findsOneWidget);
    expect(find.text('other.glb'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'catalogues the selected ref and downloads only an opened blob',
    () async {
      final requests = <http.Request>[];
      final repository = ModelViewerRepository(
        client: MockClient((request) async {
          requests.add(request);
          return _repositoryResponse(request);
        }),
        secrets: _MemorySecrets(),
      );
      addTearDown(repository.dispose);
      final catalogue = await repository.scan(
        'https://github.com/owner/repo.git/',
        ref: 'feature/assets',
      );
      expect(catalogue.models.map((model) => model.path), [
        _modelPath,
        'other.glb',
      ]);
      expect(catalogue.models.first.format, RepositoryModelFormat.obj);
      expect(requests[1].url.pathSegments.last, 'feature/assets');
      expect(requests, hasLength(3));
      expect(utf8.decode(await catalogue.read(_modelPath)), _obj);
      expect(requests.last.url.pathSegments.last, _objSha);
      expect(
        requests.every(
          (request) => !request.headers.containsKey('Authorization'),
        ),
        true,
      );
    },
  );

  test('walks subtrees when GitHub truncates the recursive result', () async {
    final repository = ModelViewerRepository(
      client: MockClient((request) async {
        if (request.url.queryParameters.containsKey('recursive')) {
          return _json({'truncated': true, 'tree': []});
        }
        if (request.url.pathSegments.last == _treeSha) {
          return _json({
            'tree': [
              {'path': 'nested', 'type': 'tree', 'sha': _folderSha},
            ],
          });
        }
        if (request.url.pathSegments.last == _folderSha) {
          return _json({
            'tree': [_blob('nested.ply', _objSha, 1)],
          });
        }
        return _repositoryResponse(request);
      }),
      secrets: _MemorySecrets(),
    );
    addTearDown(repository.dispose);
    final catalogue = await repository.scan('owner/repo');
    expect(catalogue.models.single.path, 'nested/nested.ply');
  });

  test(
    'private access stays on GitHub and disconnect clears credentials',
    () async {
      final secrets = _MemorySecrets();
      final repository = ModelViewerRepository(
        client: MockClient((request) async {
          expect(request.url.host, 'api.github.com');
          expect(request.followRedirects, false);
          if (request.headers['Authorization'] != 'Bearer test-token') {
            return http.Response('', 404);
          }
          if (request.url.path == '/user') return _json({'login': 'artist'});
          return _repositoryResponse(request);
        }),
        secrets: secrets,
      );
      addTearDown(repository.dispose);
      await expectLater(
        repository.scan('owner/repo'),
        throwsA(isA<ModelViewerException>()),
      );
      await repository.connect('test-token');
      expect(repository.githubLogin, 'artist');
      expect(secrets.value, contains('test-token'));
      final catalogue = await repository.scan('owner/repo');
      expect(utf8.decode(await catalogue.read(_modelPath)), _obj);
      await repository.disconnect();
      expect(secrets.value, isNull);
      await expectLater(
        repository.scan('owner/repo'),
        throwsA(isA<ModelViewerException>()),
      );
    },
  );

  test(
    'preview serves only the selected model and resource file types',
    () async {
      final repository = ModelViewerRepository(
        client: MockClient((request) async => _repositoryResponse(request)),
        secrets: _MemorySecrets(),
      );
      addTearDown(repository.dispose);
      final catalogue = await repository.scan('owner/repo');
      final server = await ModelPreviewServer.start(
        catalogue,
        catalogue.models.first,
        currentL,
      );
      addTearDown(server.close);
      final client = IOClient(
        HttpOverrides.runWithHttpOverrides(HttpClient.new, _LoopbackHttp()),
      );
      addTearDown(client.close);
      final home = await client.get(server.url);
      expect(home.statusCode, HttpStatus.ok);
      expect(
        home.headers['content-security-policy'],
        contains("default-src 'none'"),
      );
      final config = await client.get(server.url.resolve('config.json'));
      final file =
          (jsonDecode(config.body) as Map<String, dynamic>)['file'] as String;
      expect(file, 'files/models/cat%20%231.OBJ');
      final model = await client.get(server.url.resolve(file));
      expect(model.body, _obj);
      expect(model.headers['content-type'], 'application/octet-stream');
      expect(
        (await client.get(
          server.url.resolve('files/models/cat.png'),
        )).statusCode,
        200,
      );
      expect(
        (await client.get(server.url.resolve('files/other.glb'))).statusCode,
        404,
      );
      expect(
        (await client.get(server.url.resolve('files/readme.txt'))).statusCode,
        404,
      );
      expect(
        (await client.get(server.url.resolve('../config.json'))).statusCode,
        404,
      );
      expect(
        (await client.get(
          server.url.resolve('config.json'),
          headers: {'Sec-Fetch-Site': 'cross-site'},
        )).statusCode,
        404,
      );
    },
  );
}
