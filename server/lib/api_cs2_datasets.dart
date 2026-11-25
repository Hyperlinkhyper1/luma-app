part of 'api.dart';

extension _Cs2DatasetRoutes on Api {
  Response _cs2Catalog(Request request, StoredUser user) {
    final published = _cs2Datasets.published;
    return jsonResponse(200, {
      'canDownload': _canDownloadCs2Dataset(user),
      'rounds': published.roundCount,
      'maps': [
        for (final id in published.maps)
          {'id': id, 'rounds': published.predict(id).sampleSize},
      ],
    });
  }

  Response _cs2Prediction(Request request, StoredUser user) {
    final query = request.url.queryParameters;
    final map = cs2BombMapId(query['map'] ?? '');
    final previous = _cs2Outcome(query['previous']);
    if (map == null || (query.containsKey('previous') && previous == null)) {
      return errorResponse(400, 'invalid_prediction',
          'Choose a map and a valid previous round.');
    }
    final prediction = _cs2Datasets.published.predict(map, previous);
    return jsonResponse(200, {
      'counts': prediction.counts,
      'conditioned': prediction.conditioned,
    });
  }

  Response _cs2Download(Request request, StoredUser user) {
    if (!_canDownloadCs2Dataset(user)) {
      return errorResponse(
          403, 'paid_plan_required', 'Database downloads require a paid plan.');
    }
    final dataset = _cs2Datasets.published;
    if (dataset.roundCount == 0) {
      return errorResponse(404, 'dataset_unpublished',
          'The CS2 database has not been published yet.');
    }
    return jsonResponse(200, dataset.toJson()).change(headers: {
      'Content-Disposition': 'attachment; filename="luma-cs2-database.json"',
      'Cache-Control': 'private, no-store',
    });
  }

  bool _canDownloadCs2Dataset(StoredUser user) =>
      user.planId != 'core' && kPlanQuotaBytes.containsKey(user.planId);

  Future<Response> _cs2PrivateReplay(Request request, StoredUser user) =>
      _cs2ReplayImporter.import(request, (match, digest) {
        return jsonResponse(200, {...match.toJson(), 'digest': digest})
            .change(headers: {'Cache-Control': 'private, no-store'});
      });

  Response _adminCs2Datasets(Request request) =>
      jsonResponse(200, _cs2Datasets.status);

  Future<Response> _adminCs2Cases(Request request) =>
      _adminCs2Mutation(request, (body) async {
        final rawMap = body['map'];
        final map = rawMap is String ? cs2BombMapId(rawMap) : null;
        final rawOutcomes = body['outcomes'];
        if (map == null ||
            rawOutcomes is! List ||
            rawOutcomes.isEmpty ||
            rawOutcomes.length > cs2MaxManualRounds) {
          throw const FormatException(
              'Enter a de_ map ID and 1 to 500 round outcomes.');
        }
        final outcomes = <Cs2Outcome>[];
        for (final raw in rawOutcomes) {
          final outcome = _cs2Outcome(raw);
          if (outcome == null) {
            throw const FormatException('Each round must be A, B or Other.');
          }
          outcomes.add(outcome);
        }
        await _cs2Datasets.stage(Cs2Match(map, [outcomes]));
      });

  Future<Response> _adminCs2Publish(Request request) =>
      _adminCs2Mutation(request, (body) {
        final count = body['caseCount'];
        if (count is! int) {
          throw const FormatException('Enter a whole number of rounds.');
        }
        return _cs2Datasets.publish(count);
      });

  Future<Response> _adminCs2Mutation(
    Request request,
    Future<void> Function(Map<String, dynamic>) action,
  ) async {
    if (request.headers['content-type']?.split(';').first !=
        'application/json') {
      return errorResponse(415, 'content_type', 'Send JSON round data.');
    }
    try {
      await action(await Api._readJson(request, maxBytes: 8192));
      return _adminCs2Datasets(request);
    } on FormatException catch (error) {
      return errorResponse(400, 'invalid_cases', error.message.toString());
    }
  }

  Future<Response> _adminCs2Replay(Request request) =>
      _cs2ReplayImporter.import(request, (match, digest) async {
        try {
          await _cs2Datasets.stage(match, digest: digest);
          return _adminCs2Datasets(request);
        } on FormatException catch (error) {
          return errorResponse(400, 'invalid_cases', error.message.toString());
        }
      });
}

Cs2Outcome? _cs2Outcome(Object? raw) => switch (raw) {
      'a' => Cs2Outcome.a,
      'b' => Cs2Outcome.b,
      'other' => Cs2Outcome.other,
      _ => null,
    };
