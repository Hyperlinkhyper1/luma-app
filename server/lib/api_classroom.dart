part of 'api.dart';

/// The Text Library classroom's endpoints and its admin dashboard pieces.
/// See `classroom.dart` for what the classroom is.
extension ClassroomApi on Api {
  /// The route the tutor is served by: the operator's pick when its
  /// provider still has a key, otherwise whatever Nebula runs on.
  AiModeRoute? _aiClassroomRoute() {
    final configured = config.configuredAiUpstreams;
    final chosen = classroomConfig.config.route;
    if (chosen != null && configured.contains(chosen.upstream)) return chosen;
    return aiModeRoutes.resolve('smarter', configured);
  }

  static const _meteredMode = 'normal';

  /// Why [user] can't use the classroom right now, or null when they can.
  Response? _classroomRefusal(StoredUser user) {
    if (user.planId != kClassroomMinPlan) {
      return errorResponse(
          403, 'plan_required', 'The classroom is part of the Nova plan.');
    }
    final budget = aiTokenBudget(user.planId, _meteredMode);
    if (!aiUsage.canSpend(user.id, _meteredMode, budget)) {
      return errorResponse(
          429,
          'usage_limit',
          "You've hit your Luma AI usage limit for now — it frees up again "
              'over time, or buy extra credits.');
    }
    return null;
  }

  /// The account's classroom state: whether its plan opens the door, and
  /// the country it picked (null until it picks one).
  Future<Response> _classroomState(Request request, StoredUser user) async =>
      jsonResponse(200, {
        'allowed': user.planId == kClassroomMinPlan,
        'country': classroomCountries.countryOf(user.id),
      });

  /// Picks the account's country. Allowed once; the operator can clear it.
  Future<Response> _classroomSetCountry(
      Request request, StoredUser user) async {
    if (user.planId != kClassroomMinPlan) {
      return errorResponse(
          403, 'plan_required', 'The classroom is part of the Nova plan.');
    }
    Map<String, dynamic> body;
    try {
      body = await Api._readJson(request);
    } on FormatException {
      return errorResponse(400, 'bad_request', 'Malformed request.');
    }
    final country = cleanClassroomCountry(body['country']);
    if (country == null) {
      return errorResponse(400, 'bad_request', 'That is not a country.');
    }
    if (!await classroomCountries.setOnce(user.id, country)) {
      return errorResponse(409, 'country_locked',
          'Your country is already set. Ask the luma team to change it.');
    }
    return jsonResponse(200, {'country': country});
  }

  /// The lesson in a request, with the account's own country. Throws the
  /// response to send when there is none.
  (ClassroomLesson?, Response?) _classroomLesson(
      StoredUser user, Map<String, dynamic> body) {
    final country = classroomCountries.countryOf(user.id);
    if (country == null) {
      return (
        null,
        errorResponse(409, 'no_country', 'Pick your country first.'),
      );
    }
    final lesson = ClassroomLesson.fromJson(body['lesson'], country: country);
    if (lesson == null) {
      return (
        null,
        errorResponse(400, 'bad_request',
            'Fill in the school, year, subject, book, chapter, paragraph and topic.'),
      );
    }
    return (lesson, null);
  }

  /// One fresh call to the tutor: [messages] are the whole conversation.
  /// Tries the "if possible" model first, then the main one; returns the
  /// first reply [parse] accepts, or null.
  Future<T?> _classroomCall<T>(
    StoredUser user,
    AiModeRoute route,
    List<Map<String, String>> messages,
    T? Function(String content) parse, {
    required int maxTokens,
    required double temperature,
  }) async {
    final candidates = await _aiCandidates('classroom', route);
    if (candidates.isEmpty) {
      stderr.writeln('[luma] classroom tutor: no model to call '
          '(every classroom model is paused by the price guard)');
    }
    String snippet(String s) {
      final flat = s.replaceAll(RegExp(r'\s+'), ' ');
      return flat.length > 300 ? '${flat.substring(0, 300)}…' : flat;
    }

    for (final candidate in candidates) {
      final model = candidate.route.model;
      try {
        final upstreamBody = Api._aiUpstreamBody({
          'messages': messages,
          'max_tokens': maxTokens,
          'temperature': temperature,
        }, candidate.route);
        _applyAiMaxPrice(candidate.key, candidate.route, upstreamBody);
        final (status, responseBody) =
            await _callAiUpstream(candidate.route, upstreamBody);
        if (status != HttpStatus.ok) {
          stderr.writeln('[luma] classroom tutor: $model answered $status: '
              '${snippet(responseBody)}');
          continue;
        }
        await _recordAiPaid(candidate.key, candidate.route, responseBody);
        await _logAiCall(user, 'Classroom', candidate.route, responseBody);
        var tokens = 0;
        String? content;
        try {
          final decoded = jsonDecode(responseBody);
          if (decoded is Map) {
            tokens = (decoded['usage']?['total_tokens'] as num?)?.toInt() ?? 0;
            content = decoded['choices']?[0]?['message']?['content'] as String?;
          }
        } catch (_) {}
        await aiUsage.charge(user.id, tokens > 0 ? tokens : 800, _meteredMode,
            aiTokenBudget(user.planId, _meteredMode));
        final parsed = content == null ? null : parse(content);
        if (parsed != null) return parsed;
        stderr.writeln('[luma] classroom tutor: $model sent an unusable '
            'reply: ${snippet(content ?? responseBody)}');
      } catch (e) {
        stderr.writeln('[luma] classroom tutor: $model failed: $e');
      }
    }
    return null;
  }

  /// The next question about the lesson's paragraph. A fresh call every
  /// time; only the earlier questions' text comes along, to avoid repeats.
  Future<Response> _classroomQuestion(Request request, StoredUser user) async {
    if (_classroomRefusal(user) case final refusal?) return refusal;
    Map<String, dynamic> body;
    try {
      body = await Api._readJson(request);
    } on FormatException {
      return errorResponse(400, 'bad_request', 'Malformed request.');
    }
    final (lesson, error) = _classroomLesson(user, body);
    if (lesson == null) return error!;
    final route = _aiClassroomRoute();
    if (route == null) {
      return errorResponse(
          404, 'not_configured', 'No server-wide Luma AI key is configured.');
    }
    final asked = [
      if (body['asked'] case final List list)
        for (final q in list)
          if (q is String) q,
    ];
    final number = (body['number'] as num?)?.toInt() ?? asked.length + 1;
    final language =
        body['language'] is String ? body['language'] as String : null;
    final question = await _classroomCall(
      user,
      route,
      classroomQuestionMessages(
          classroomConfig.config.effectiveInstructions, lesson,
          asked: asked, number: number.clamp(1, 999), language: language),
      parseClassroomQuestion,
      maxTokens: 1500,
      temperature: 0.8,
    );
    // 503, not 502: Cloudflare swaps an origin 502/504 for its own page,
    // and the app would lose this message.
    if (question == null) {
      return errorResponse(503, 'upstream_error',
          'The teacher could not think of a question. Try again.');
    }
    return jsonResponse(200, question.toJson());
  }

  /// Checks a handed-in lesson. Each answer is its own fresh call with only
  /// the lesson, that question and that answer, a few at a time.
  Future<Response> _classroomReview(Request request, StoredUser user) async {
    if (_classroomRefusal(user) case final refusal?) return refusal;
    Map<String, dynamic> body;
    try {
      body = await Api._readJson(request);
    } on FormatException {
      return errorResponse(400, 'bad_request', 'Malformed request.');
    }
    final (lesson, error) = _classroomLesson(user, body);
    if (lesson == null) return error!;
    final route = _aiClassroomRoute();
    if (route == null) {
      return errorResponse(
          404, 'not_configured', 'No server-wide Luma AI key is configured.');
    }
    final rawItems = body['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      return errorResponse(400, 'bad_request', 'Nothing to hand in.');
    }
    if (rawItems.length > kClassroomMaxItems) {
      return errorResponse(400, 'too_many',
          'Hand in at most $kClassroomMaxItems questions at a time.');
    }
    final items = rawItems.map(ClassroomItem.fromJson).toList();
    final language =
        body['language'] is String ? body['language'] as String : null;
    final instructions = classroomConfig.config.effectiveInstructions;
    final results = List<ClassroomReview?>.filled(items.length, null);
    const parallel = 4;
    for (var start = 0; start < items.length; start += parallel) {
      await Future.wait([
        for (var i = start; i < items.length && i < start + parallel; i++)
          if (items[i] case final item?)
            _classroomCall(
              user,
              route,
              classroomReviewMessages(instructions, lesson, item,
                  language: language),
              parseClassroomReview,
              maxTokens: 1200,
              temperature: 0.2,
            ).then((review) => results[i] = review),
      ]);
    }
    if (results.every((r) => r == null)) {
      return errorResponse(503, 'upstream_error',
          'The teacher could not check your answers. Try again.');
    }
    return jsonResponse(200, {
      'results': [for (final r in results) r?.toJson()],
    });
  }

  /// Saves the Assistant tab's classroom tutor card. A blank model falls
  /// back to Nebula's route; blank or "reset" instructions fall back to the
  /// built-in ones.
  Future<Response> _adminAiClassroomSave(Request request) async {
    Map<String, String> form = const {};
    try {
      form = Uri.splitQueryString(await request.readAsString());
    } catch (_) {}
    AiModeRoute? route;
    final model = (form['classroom.model'] ?? '').trim();
    if (model.isNotEmpty) {
      final upstream = AiUpstream.parse(form['classroom.upstream']);
      if (upstream == null) {
        return errorResponse(
            400, 'bad_request', 'Unknown provider for the classroom tutor.');
      }
      if (!isValidAiModelId(model)) {
        return errorResponse(
            400, 'bad_request', '"$model" is not a valid model id.');
      }
      final effort = form['classroom.effort'] ?? '';
      if (!kAiReasoningEfforts.contains(effort)) {
        return errorResponse(400, 'bad_request',
            'Unknown reasoning effort for the classroom tutor.');
      }
      route = AiModeRoute(upstream, model,
          reasoningEffort: effort.isEmpty ? null : effort);
    }
    var instructions =
        (form['classroom.instructions'] ?? '').replaceAll('\r\n', '\n').trim();
    if (instructions.length > kClassroomMaxInstructionChars) {
      return errorResponse(400, 'bad_request',
          'Instructions are limited to $kClassroomMaxInstructionChars characters.');
    }
    if (form['classroom.reset'] == '1' ||
        instructions == kDefaultClassroomInstructions.trim()) {
      instructions = '';
    }
    final preferred = Api._formPreferredRoute(form, 'classroom');
    if (preferred.error != null) {
      return errorResponse(400, 'bad_request', preferred.error!);
    }
    final saved = ClassroomConfig(
        route: route, instructions: instructions.isEmpty ? null : instructions);
    await classroomConfig.save(saved);
    await aiPreferred.save('classroom', preferred.route);
    await store.logActivity(
        'ai_routes_changed',
        'Classroom tutor model → ${route?.model ?? 'Nebula default'}'
            '${preferred.route == null ? '' : ' (if possible ${preferred.route!.model})'}, '
            '${saved.instructions == null ? 'default' : 'custom'} instructions');
    return _adminFormResponse(request, '/admin', fragment: 'assistant', json: {
      'ok': true,
      ...saved.toJson(),
      if (preferred.route != null) 'preferred': preferred.route!.toJson(),
    });
  }

  /// Clears an account's classroom country from the Users tab, so the
  /// reader can pick again (they moved, or picked the wrong one).
  Future<Response> _adminClassroomCountryReset(Request request) async {
    Map<String, String> form = const {};
    try {
      form = Uri.splitQueryString(await request.readAsString());
    } catch (_) {}
    final email = form['email']?.trim().toLowerCase();
    final userId = email == null ? null : store.userIdByEmail[email];
    if (userId == null) {
      return errorResponse(404, 'not_found', 'No account with that email.');
    }
    final was = classroomCountries.countryOf(userId);
    await classroomCountries.reset(userId);
    if (was != null) {
      await store.logActivity('classroom_country_reset',
          '$email can pick their classroom country again (was $was)');
    }
    return _adminFormResponse(request, '/admin',
        fragment: 'users', json: {'ok': true, 'was': was});
  }

  /// The Assistant tab's classroom tutor card.
  String _adminAiClassroomCard(Set<AiUpstream> configured) {
    final saved = classroomConfig.config;
    return _adminAiReviewerCard(
      configured,
      mode: 'classroom',
      title: 'Classroom tutor model',
      description: 'The model behind the Text Library\'s classroom (Nova '
          'only): it hands out questions about the paragraph a reader is '
          'practising and checks their answers when they hand in. Every '
          'question and every check is a fresh call carrying only these '
          'instructions and the lesson — country, school, year, level, '
          'subject, book, chapter, paragraph and topic. The answer formats '
          'are added automatically after your instructions. Each call counts '
          'against the user\'s Aurora usage limit.',
      action: '/admin/ai-classroom',
      stored: saved.route,
      live: _aiClassroomRoute(),
      instructions: saved.instructions,
      defaultInstructions: kDefaultClassroomInstructions,
      maxInstructionChars: kClassroomMaxInstructionChars,
      saveLabel: 'Save classroom tutor',
    );
  }
}
