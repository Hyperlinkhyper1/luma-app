part of 'api.dart';

extension MealChefApi on Api {
  /// The Recipe Book meal planner's chef: Nebula plans one meal from the
  /// household's answers under the fixed [kMealChefInstructions]. Orbit and
  /// Nova only, and paid for from the weekly Luma AI allowance alone — a
  /// reservation is taken before the call and settled to the real cost.
  Future<Response> _aiMealChef(Request request, StoredUser user) async {
    if (!mealChefAllowed(user.planId)) {
      return errorResponse(403, 'plan_required', mealChefPlanMessage);
    }
    final MealChefInput input;
    try {
      input = MealChefInput.parse(
          await Api._readJson(request, maxBytes: kMealChefMaxBodyBytes));
    } on FormatException catch (e) {
      return errorResponse(400, 'bad_request', e.message.toString());
    }
    final route = aiModeRoutes.resolve(
        kMealChefSelector, config.configuredAiUpstreams);
    if (route == null) {
      return errorResponse(
          404, 'not_configured', 'No server-wide Luma AI key is configured.');
    }
    if (!_mealChefPending.add(user.id)) {
      return errorResponse(409, 'already_cooking',
          'The chef is still working on your last meal.');
    }
    final budget = aiTokenBudget(user.planId);
    String? reservation;
    var settled = false;
    try {
      reservation = await aiUsage.reserveWeeklyOnly(
          user.id,
          aiUsageUnits(kMealChefReserveTokens, kMealChefSelector).toDouble(),
          budget);
      if (reservation == null) {
        return errorResponse(
            429,
            'weekly_usage_limit',
            "There isn't enough of your weekly Luma AI limit left for the "
                'chef — it frees up again over the coming days.');
      }
      final candidates = await _aiCandidates(kMealChefSelector, route);
      if (candidates.isEmpty) {
        return errorResponse(503, 'model_disabled',
            'The meal chef is paused right now. Try again later.');
      }
      final messages = mealChefMessages(input);
      var spentTokens = 0;
      var answered = false;
      try {
        for (final candidate in candidates) {
          final upstreamBody = Api._aiUpstreamBody({
            'messages': messages,
            'max_tokens': 4000,
            'temperature': 0.7,
          }, candidate.route);
          _applyAiMaxPrice(candidate.key, candidate.route, upstreamBody);
          final int status;
          final String responseBody;
          try {
            (status, responseBody) =
                await _callMealChefUpstream(candidate.route, upstreamBody)
                    .timeout(const Duration(seconds: 80));
          } catch (_) {
            continue;
          }
          if (status != HttpStatus.ok) continue;
          answered = true;
          await _recordAiPaid(candidate.key, candidate.route, responseBody);
          await _logAiCall(user, 'Meal chef', candidate.route, responseBody);
          var tokens = 0;
          String? content;
          try {
            final decoded = jsonDecode(responseBody);
            if (decoded is Map) {
              tokens =
                  (decoded['usage']?['total_tokens'] as num?)?.toInt() ?? 0;
              content =
                  decoded['choices']?[0]?['message']?['content'] as String?;
            }
          } catch (_) {}
          spentTokens += tokens > 0 ? tokens : kMealChefReserveTokens;
          final meal = content == null
              ? null
              : parseMealChefReply(content, input.dealIds);
          if (meal != null) return jsonResponse(200, meal.toJson());
        }
      } finally {
        if (answered) {
          await aiUsage.settleWeeklyOnly(user.id, reservation,
              aiUsageUnits(spentTokens, kMealChefSelector).toDouble());
          settled = true;
        }
      }
      return answered
          ? errorResponse(502, 'upstream_error',
              'The chef did not answer in a usable form. Try again.')
          : errorResponse(
              502, 'upstream_error', 'Could not reach the AI service.');
    } finally {
      if (!settled && reservation != null) {
        await aiUsage.releaseWeeklyOnly(user.id, reservation);
      }
      _mealChefPending.remove(user.id);
    }
  }

  Future<(int, String)> _callMealChefUpstream(
          AiModeRoute route, Map<String, dynamic> upstreamBody) =>
      mealChefCall != null
          ? mealChefCall!(route, upstreamBody)
          : _callAiUpstream(route, upstreamBody);
}
