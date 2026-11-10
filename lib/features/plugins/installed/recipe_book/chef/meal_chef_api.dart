import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../../sync/server_access.dart';
import '../../groceries/groceries_api.dart';
import 'meal_chef_models.dart';

/// Why the chef could not plan a meal. [code] is the server's error code
/// (`plan_required`, `weekly_usage_limit`, …) when there was one.
class MealChefException implements Exception {
  const MealChefException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Sends the household's answers to the luma server, where Nebula plans the
/// meal under fixed chef instructions. Like everything that talks to a luma
/// server, only through [GatedServerClient].
class MealChefApi {
  MealChefApi(String baseUrl, {this.token, http.Client? client})
      : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = GatedServerClient(inner: client);

  final String baseUrl;
  final String? token;
  final http.Client _client;

  static const _timeout = Duration(seconds: 100);

  /// The request body for [answers]. [previous] and [feedback] ask for a
  /// changed meal. Deals only travel when the household asked for them.
  static Map<String, Object?> requestBody({
    required MealChefAnswers answers,
    required String language,
    List<RemoteProduct> deals = const [],
    ChefMeal? previous,
    List<String> feedback = const [],
  }) =>
      {
        'language': language,
        'people': answers.people,
        'allergies': answers.allergies,
        if (answers.useDeals != null) 'useDeals': answers.useDeals,
        'stores': answers.stores,
        'notes': answers.notes,
        if (answers.useDeals == true)
          'deals': [for (final d in deals) _dealJson(d)],
        if (previous != null) 'previous': previous.toJson(),
        if (feedback.isNotEmpty) 'feedback': feedback,
      };

  static String _dealName(RemoteProduct p) {
    final brand = p.brand?.trim() ?? '';
    if (brand.isEmpty || p.name.toLowerCase().contains(brand.toLowerCase())) {
      return p.name;
    }
    return '$brand ${p.name}';
  }

  static Map<String, Object> _dealJson(RemoteProduct p) => {
        'id': p.id,
        'store': p.market.slug,
        'name': _dealName(p),
        if (p.price != null) 'price': '€${p.price!.toStringAsFixed(2)}',
        if (p.oldPrice != null) 'oldPrice': '€${p.oldPrice!.toStringAsFixed(2)}',
        if (p.discountText case final text? when text.isNotEmpty)
          'discount': text,
        if (p.quantity case final q? when q.isNotEmpty) 'quantity': q,
      };

  Future<ChefMeal> plan(
    Map<String, Object?> body, {
    required String signIn,
    required String unreachable,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/ai/meal-chef'),
            headers: {
              'Content-Type': 'application/json',
              if (token case final value?) 'Authorization': 'Bearer $value',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on ServerAccessDeniedException {
      throw MealChefException(signIn);
    } catch (_) {
      throw MealChefException(unreachable);
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode != 200) {
      final message = decoded is Map ? decoded['message'] : null;
      final code = decoded is Map ? decoded['error'] : null;
      throw MealChefException(
        message is String && message.isNotEmpty
            ? message
            : 'HTTP ${response.statusCode}',
        code: code is String ? code : null,
      );
    }
    final meal = ChefMeal.tryParse(decoded);
    if (meal == null) throw MealChefException(unreachable);
    return meal;
  }

  void close() => _client.close();
}
