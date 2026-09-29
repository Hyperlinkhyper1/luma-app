import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_model_sources.dart';
import 'package:test/test.dart';

void main() {
  test('fetch keeps all vendors and variants for routing only', () async {
    final fetcher = AiCatalogFetcher(
        client: _Client(jsonEncode({
      'data': [
        for (final id in [
          'openai/model',
          'inclusionai/ling-3.0-flash-vl',
          'new-vendor/model:free',
          '~new-vendor/model-latest'
        ])
          {
            'id': id,
            'pricing': {'prompt': '0.000000021', 'completion': '0.0000000616'}
          },
      ],
    })));
    addTearDown(fetcher.close);
    final result = await fetcher.fetchOpenRouter();
    expect(result.result.ok, isTrue);
    expect(result.models.map((model) => model.id), ['openai/model']);
    expect(result.routingModels.map((model) => model.id), [
      'openai/model',
      'inclusionai/ling-3.0-flash-vl',
      'new-vendor/model:free',
      '~new-vendor/model-latest',
    ]);
    expect(result.routingModels[1].inputPricePerM, closeTo(0.021, 1e-9));
  });
}

class _Client implements HttpClient {
  _Client(this.body);
  final String body;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(body);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  _Request(this.body);
  final String body;
  @override
  HttpHeaders get headers => _Headers();
  @override
  Future<HttpClientResponse> close() async => _Response(body);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.body);
  final String body;
  @override
  int get statusCode => 200;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream.value(utf8.encode(body)).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
