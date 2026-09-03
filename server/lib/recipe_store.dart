import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'util.dart';

/// A recipe someone has published to the shared, cross-account "Public"
/// catalogue. Unlike the zero-knowledge sync collections in store.dart, this
/// content is deliberately public — every signed-in user can browse, rate and
/// review it — so it lives in its own plain (non-encrypted) store, mirroring
/// the conventions in chat_store.dart / subway_store.dart.
///
/// The recipe body itself (ingredients, steps) is small JSON kept inline; the
/// optional hero photo is stored as a separate binary file under
/// `recipe_media/` (see [RecipeStore]) and referenced here only by [photoId],
/// for the same reason Store keeps blobs out of collections.json.
class PublicRecipe {
  PublicRecipe({
    required this.id,
    required this.authorId,
    required this.authorEmail,
    required this.title,
    required this.description,
    required this.category,
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.ingredients,
    required this.steps,
    required this.createdAtMs,
    this.updatedAtMs,
    this.photoId,
  });

  final String id;
  final String authorId;
  final String authorEmail;
  String title;
  String? description;
  String category;
  int servings;
  int prepMinutes;
  int cookMinutes;

  /// Opaque JSON strings, validated for shape/size on the way in but stored
  /// as-is — the server never needs to interpret an ingredient or a step.
  String ingredients;
  String steps;

  final int createdAtMs;
  int? updatedAtMs;

  /// Filename (without directory) of the hero photo under `recipe_media/`, or
  /// null if the author never uploaded one.
  String? photoId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorEmail': authorEmail,
        'title': title,
        'description': description,
        'category': category,
        'servings': servings,
        'prepMinutes': prepMinutes,
        'cookMinutes': cookMinutes,
        'ingredients': ingredients,
        'steps': steps,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        'photoId': photoId,
      };

  factory PublicRecipe.fromJson(Map<String, dynamic> j) => PublicRecipe(
        id: j['id'] as String,
        authorId: j['authorId'] as String,
        authorEmail: j['authorEmail'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String?,
        category: j['category'] as String? ?? 'Other',
        servings: j['servings'] as int? ?? 2,
        prepMinutes: j['prepMinutes'] as int? ?? 0,
        cookMinutes: j['cookMinutes'] as int? ?? 0,
        ingredients: j['ingredients'] as String? ?? '[]',
        steps: j['steps'] as String? ?? '[]',
        createdAtMs: j['createdAtMs'] as int? ?? 0,
        updatedAtMs: j['updatedAtMs'] as int?,
        photoId: j['photoId'] as String?,
      );
}

/// One user's rating + written review of a [PublicRecipe]. At most one review
/// per (user, recipe) pair — re-reviewing updates the existing entry. The
/// optional photo is again stored as a binary file and referenced by id.
class RecipeReview {
  RecipeReview({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.userEmail,
    required this.rating,
    required this.text,
    required this.createdAtMs,
    this.updatedAtMs,
    this.photoId,
  });

  final String id;
  final String recipeId;
  final String userId;
  final String userEmail;
  int rating; // 1..5
  String text;
  final int createdAtMs;
  int? updatedAtMs;
  String? photoId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipeId': recipeId,
        'userId': userId,
        'userEmail': userEmail,
        'rating': rating,
        'text': text,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        'photoId': photoId,
      };

  factory RecipeReview.fromJson(Map<String, dynamic> j) => RecipeReview(
        id: j['id'] as String,
        recipeId: j['recipeId'] as String,
        userId: j['userId'] as String,
        userEmail: j['userEmail'] as String? ?? '',
        rating: j['rating'] as int? ?? 0,
        text: j['text'] as String? ?? '',
        createdAtMs: j['createdAtMs'] as int? ?? 0,
        updatedAtMs: j['updatedAtMs'] as int?,
        photoId: j['photoId'] as String?,
      );
}

/// File-backed store for the public recipe catalogue: recipe metadata and
/// reviews each in their own JSON file, and hero/review photos as individual
/// binary files under `recipe_media/` (same split Store uses for blobs and
/// SubwayStore uses for state snapshots). Mutations should run under the
/// shared `Store.lock` at the call site so writes never interleave.
class RecipeStore {
  RecipeStore._(this.rootPath);

  final String rootPath;

  final Map<String, PublicRecipe> recipesById = {};

  /// Reviews grouped by recipe id, each list kept newest-first.
  final Map<String, List<RecipeReview>> reviewsByRecipeId = {};

  static const _mediaDir = 'recipe_media';

  /// Cap on a single uploaded photo. The client downscales before sending, so
  /// this is a generous safety ceiling rather than an expected size.
  static const maxPhotoBytes = 4 * 1024 * 1024;

  String get _recipesFile => '$rootPath/recipes.json';
  String get _reviewsFile => '$rootPath/recipe_reviews.json';
  String _mediaPath(String photoId) => '$rootPath/$_mediaDir/$photoId';

  static Future<RecipeStore> open(String path) async {
    final store = RecipeStore._(path);
    await Directory('$path/$_mediaDir').create(recursive: true);

    for (final r in await _readJsonList(store._recipesFile)) {
      final recipe = PublicRecipe.fromJson(r as Map<String, dynamic>);
      store.recipesById[recipe.id] = recipe;
    }
    for (final rv in await _readJsonList(store._reviewsFile)) {
      final review = RecipeReview.fromJson(rv as Map<String, dynamic>);
      store.reviewsByRecipeId
          .putIfAbsent(review.recipeId, () => [])
          .add(review);
    }
    for (final list in store.reviewsByRecipeId.values) {
      list.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    }
    return store;
  }

  static Future<List<dynamic>> _readJsonList(String path) async {
    final file = File(path);
    if (!await file.exists()) return const [];
    final decoded = jsonDecode(await file.readAsString());
    return decoded is List ? decoded : const [];
  }

  // ---- Persistence ---------------------------------------------------------

  Future<void> saveRecipes() => atomicWriteString(_recipesFile,
      jsonEncode(recipesById.values.map((r) => r.toJson()).toList()));

  Future<void> saveReviews() => atomicWriteString(
      _reviewsFile,
      jsonEncode(reviewsByRecipeId.values
          .expand((list) => list)
          .map((r) => r.toJson())
          .toList()));

  // ---- Queries -------------------------------------------------------------

  /// The catalogue, newest first, capped so a huge library can't blow up a
  /// single list response.
  List<PublicRecipe> browse({int limit = 300}) {
    final all = recipesById.values.toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return all.length > limit ? all.sublist(0, limit) : all;
  }

  List<RecipeReview> reviewsFor(String recipeId) =>
      reviewsByRecipeId[recipeId] ?? const [];

  RecipeReview? reviewBy(String recipeId, String userId) {
    for (final r in reviewsFor(recipeId)) {
      if (r.userId == userId) return r;
    }
    return null;
  }

  ({int count, double avg}) ratingSummary(String recipeId) {
    final reviews = reviewsFor(recipeId);
    if (reviews.isEmpty) return (count: 0, avg: 0);
    final sum = reviews.fold<int>(0, (a, r) => a + r.rating);
    return (count: reviews.length, avg: sum / reviews.length);
  }

  // ---- Media ---------------------------------------------------------------

  Future<void> writeMedia(String photoId, List<int> bytes) =>
      atomicWriteBytes(_mediaPath(photoId), bytes);

  Future<Uint8List?> readMedia(String photoId) async {
    final file = File(_mediaPath(photoId));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> deleteMedia(String? photoId) async {
    if (photoId == null) return;
    final file = File(_mediaPath(photoId));
    if (await file.exists()) await file.delete();
  }

  /// Removes a recipe, its reviews and every associated photo.
  Future<void> deleteRecipe(String recipeId) async {
    final recipe = recipesById.remove(recipeId);
    await deleteMedia(recipe?.photoId);
    final reviews = reviewsByRecipeId.remove(recipeId) ?? const [];
    for (final r in reviews) {
      await deleteMedia(r.photoId);
    }
    await saveRecipes();
    await saveReviews();
  }
}
