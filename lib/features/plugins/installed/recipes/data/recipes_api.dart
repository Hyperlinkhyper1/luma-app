import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../recipes_models.dart';

/// Raised for every non-successful server response from the recipe endpoints,
/// mirroring [ChatApiException] in the chat plugin.
class RecipeApiException implements Exception {
  const RecipeApiException(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  bool get isNotFound => status == 404;

  @override
  String toString() => message;
}

/// Thin typed HTTP client for the Recipes plugin's shared (cross-account)
/// server endpoints — the public catalogue, its reviews, and photo blobs.
/// Deliberately separate from the zero-knowledge sync API: public recipes are
/// meant to be seen by everyone, so nothing here is encrypted. Same shape as
/// the chat plugin's [ChatApi].
class RecipeApi {
  RecipeApi(String baseUrl, {this.token, http.Client? client})
      : baseUrl = _normalizeBaseUrl(baseUrl),
        _client = client ?? http.Client();

  final String baseUrl;
  String? token;
  final http.Client _client;

  static const _timeout = Duration(seconds: 30);
  static const _photoTimeout = Duration(seconds: 60);

  static String _normalizeBaseUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Uri _uri(String path) => Uri.parse('$baseUrl/api/v1$path');

  Map<String, String> get _authHeaders =>
      {if (token != null) 'Authorization': 'Bearer $token'};

  Future<List<PublicRecipe>> listRecipes() async {
    final response =
        await _client.get(_uri('/recipes'), headers: _authHeaders).timeout(_timeout);
    final body = _decodeOrThrow(response);
    return (body['recipes'] as List? ?? const [])
        .map((r) => PublicRecipe.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<PublicRecipe> getRecipe(String id) async {
    final response = await _client
        .get(_uri('/recipes/$id'), headers: _authHeaders)
        .timeout(_timeout);
    return PublicRecipe.fromJson(_decodeOrThrow(response));
  }

  Future<PublicRecipe> publish({
    required String title,
    String? description,
    required String category,
    required int servings,
    required int prepMinutes,
    required int cookMinutes,
    required List<RecipeIngredient> ingredients,
    required List<String> steps,
  }) async =>
      PublicRecipe.fromJson(await _postJson('/recipes', {
        'title': title,
        'description': description,
        'category': category,
        'servings': servings,
        'prepMinutes': prepMinutes,
        'cookMinutes': cookMinutes,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'steps': steps,
      }));

  Future<PublicRecipe> updateRecipe(
    String id, {
    required String title,
    String? description,
    required String category,
    required int servings,
    required int prepMinutes,
    required int cookMinutes,
    required List<RecipeIngredient> ingredients,
    required List<String> steps,
  }) async =>
      PublicRecipe.fromJson(await _sendJson('PUT', '/recipes/$id', {
        'title': title,
        'description': description,
        'category': category,
        'servings': servings,
        'prepMinutes': prepMinutes,
        'cookMinutes': cookMinutes,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'steps': steps,
      }));

  Future<void> deleteRecipe(String id) async {
    final response = await _client
        .delete(_uri('/recipes/$id'), headers: _authHeaders)
        .timeout(_timeout);
    _decodeOrThrow(response);
  }

  Future<PublicRecipe> putReview(String recipeId,
          {required int rating, required String text}) async =>
      PublicRecipe.fromJson(await _postJson(
          '/recipes/$recipeId/reviews', {'rating': rating, 'text': text}));

  Future<PublicRecipe> deleteReview(String recipeId) async {
    final response = await _client
        .delete(_uri('/recipes/$recipeId/reviews'), headers: _authHeaders)
        .timeout(_timeout);
    return PublicRecipe.fromJson(_decodeOrThrow(response));
  }

  /// Uploads the recipe's hero photo (raw JPEG bytes). Returns its photo id.
  Future<String> uploadRecipePhoto(String recipeId, Uint8List bytes) =>
      _uploadPhoto('/recipes/$recipeId/photo', bytes);

  /// Uploads a photo for the caller's own review of [recipeId].
  Future<String> uploadReviewPhoto(String recipeId, Uint8List bytes) =>
      _uploadPhoto('/recipes/$recipeId/reviews/photo', bytes);

  Future<String> _uploadPhoto(String path, Uint8List bytes) async {
    final response = await _client
        .post(_uri(path),
            headers: {..._authHeaders, 'Content-Type': 'image/jpeg'},
            body: bytes)
        .timeout(_photoTimeout);
    final body = _decodeOrThrow(response);
    return body['photoId'] as String? ?? '';
  }

  /// Fetches a photo blob by id. Returns null on 404, throws on other errors.
  Future<Uint8List?> fetchMedia(String photoId) async {
    final response = await _client
        .get(_uri('/recipes/media/$photoId'), headers: _authHeaders)
        .timeout(_photoTimeout);
    if (response.statusCode == 404) return null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw RecipeApiException(
        response.statusCode, 'http_${response.statusCode}', 'Could not load photo.');
  }

  Future<Map<String, dynamic>> _postJson(
          String path, Map<String, dynamic> body) =>
      _sendJson('POST', path, body);

  Future<Map<String, dynamic>> _sendJson(
      String method, String path, Map<String, dynamic> body) async {
    final request = http.Request(method, _uri(path))
      ..headers.addAll({..._authHeaders, 'Content-Type': 'application/json'})
      ..body = jsonEncode(body);
    final streamed = await _client.send(request).timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    return _decodeOrThrow(response);
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(utf8.decode(response.bodyBytes));
      if (raw is Map<String, dynamic>) decoded = raw;
    } catch (_) {}

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? const {};
    }
    throw RecipeApiException(
      response.statusCode,
      decoded?['error'] as String? ?? 'http_${response.statusCode}',
      decoded?['message'] as String? ?? 'Server error (${response.statusCode}).',
    );
  }

  void close() => _client.close();
}
