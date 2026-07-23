import 'package:flutter/material.dart';

import '../../../../theme/luma_theme.dart';

/// Categories a recipe can be filed under. 'All' is a filter-only pseudo
/// category and never stored on a recipe.
const kRecipeCategories = [
  'Breakfast',
  'Lunch',
  'Dinner',
  'Dessert',
  'Snack',
  'Drink',
  'Baking',
  'Other',
];

const kRecipeUnits = [
  '',
  'g',
  'kg',
  'ml',
  'l',
  'tsp',
  'tbsp',
  'cup',
  'oz',
  'lb',
  'piece',
  'slice',
  'pinch',
  'to taste',
];

Color recipeCategoryColor(String category, LumaPalette luma) =>
    switch (category) {
      'Breakfast' => const Color(0xFFE8A33D),
      'Lunch' => const Color(0xFF3DAE8A),
      'Dinner' => const Color(0xFF5B6CE0),
      'Dessert' => const Color(0xFFE05BA0),
      'Snack' => const Color(0xFFE07A3D),
      'Drink' => const Color(0xFF3DB8E0),
      'Baking' => const Color(0xFFCB8A5E),
      _ => luma.textMuted,
    };

String formatRecipeTime(int minutes) {
  if (minutes <= 0) return '';
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// A single ingredient line. Shared by local and public recipes; the same
/// JSON shape the server validates and stores.
class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    required this.amount,
    required this.unit,
  });

  final String name;
  final String amount;
  final String unit;

  Map<String, dynamic> toJson() =>
      {'name': name, 'amount': amount, 'unit': unit};

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
        name: j['name'] as String? ?? '',
        amount: j['amount'] as String? ?? '',
        unit: j['unit'] as String? ?? '',
      );
}

/// A recipe the user created, held locally (the "Private" tab). The optional
/// hero photo lives as a file on disk ([photoPath]); when the recipe is
/// published, [publicId] is the id it was given on the server.
class LocalRecipe {
  LocalRecipe({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.ingredients,
    required this.steps,
    this.photoPath,
    this.isFavorite = false,
    this.publicId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String category;
  final int servings;
  final int prepMinutes;
  final int cookMinutes;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final String? photoPath;
  final bool isFavorite;
  final String? publicId;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalMinutes => prepMinutes + cookMinutes;
  bool get isPublished => publicId != null;

  LocalRecipe copyWith({
    String? title,
    Object? description = _sentinel,
    String? category,
    int? servings,
    int? prepMinutes,
    int? cookMinutes,
    List<RecipeIngredient>? ingredients,
    List<String>? steps,
    Object? photoPath = _sentinel,
    bool? isFavorite,
    Object? publicId = _sentinel,
    DateTime? updatedAt,
  }) =>
      LocalRecipe(
        id: id,
        title: title ?? this.title,
        description:
            description == _sentinel ? this.description : description as String?,
        category: category ?? this.category,
        servings: servings ?? this.servings,
        prepMinutes: prepMinutes ?? this.prepMinutes,
        cookMinutes: cookMinutes ?? this.cookMinutes,
        ingredients: ingredients ?? this.ingredients,
        steps: steps ?? this.steps,
        photoPath:
            photoPath == _sentinel ? this.photoPath : photoPath as String?,
        isFavorite: isFavorite ?? this.isFavorite,
        publicId: publicId == _sentinel ? this.publicId : publicId as String?,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'servings': servings,
        'prepMinutes': prepMinutes,
        'cookMinutes': cookMinutes,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'steps': steps,
        'photoPath': photoPath,
        'isFavorite': isFavorite,
        'publicId': publicId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory LocalRecipe.fromJson(Map<String, dynamic> j) => LocalRecipe(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        description: j['description'] as String?,
        category: j['category'] as String? ?? 'Other',
        servings: j['servings'] as int? ?? 2,
        prepMinutes: j['prepMinutes'] as int? ?? 0,
        cookMinutes: j['cookMinutes'] as int? ?? 0,
        ingredients: (j['ingredients'] as List? ?? const [])
            .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        steps: (j['steps'] as List? ?? const []).cast<String>(),
        photoPath: j['photoPath'] as String?,
        isFavorite: j['isFavorite'] as bool? ?? false,
        publicId: j['publicId'] as String?,
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt:
            DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );

  static const _sentinel = Object();
}

/// A recipe published to the shared server catalogue (the "Public" tab), as
/// seen by the current user. [mine] means the viewer is its author; [myRating]
/// is the viewer's own star rating if they've reviewed it.
class PublicRecipe {
  const PublicRecipe({
    required this.id,
    required this.authorName,
    required this.mine,
    required this.title,
    this.description,
    required this.category,
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.ingredients,
    required this.steps,
    this.photoId,
    required this.createdAtMs,
    required this.ratingCount,
    required this.ratingAvg,
    this.myRating,
    this.reviews = const [],
  });

  final String id;
  final String authorName;
  final bool mine;
  final String title;
  final String? description;
  final String category;
  final int servings;
  final int prepMinutes;
  final int cookMinutes;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final String? photoId;
  final int createdAtMs;
  final int ratingCount;
  final double ratingAvg;
  final int? myRating;
  final List<RecipeReview> reviews;

  int get totalMinutes => prepMinutes + cookMinutes;

  factory PublicRecipe.fromJson(Map<String, dynamic> j) => PublicRecipe(
        id: j['id'] as String,
        authorName: j['authorName'] as String? ?? 'Someone',
        mine: j['mine'] as bool? ?? false,
        title: j['title'] as String? ?? '',
        description: j['description'] as String?,
        category: j['category'] as String? ?? 'Other',
        servings: j['servings'] as int? ?? 2,
        prepMinutes: j['prepMinutes'] as int? ?? 0,
        cookMinutes: j['cookMinutes'] as int? ?? 0,
        ingredients: (j['ingredients'] as List? ?? const [])
            .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        steps: (j['steps'] as List? ?? const []).cast<String>(),
        photoId: j['photoId'] as String?,
        createdAtMs: j['createdAtMs'] as int? ?? 0,
        ratingCount: j['ratingCount'] as int? ?? 0,
        ratingAvg: (j['ratingAvg'] as num?)?.toDouble() ?? 0,
        myRating: j['myRating'] as int?,
        reviews: (j['reviews'] as List? ?? const [])
            .map((e) => RecipeReview.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One rating + written review of a [PublicRecipe].
class RecipeReview {
  const RecipeReview({
    required this.id,
    required this.authorName,
    required this.mine,
    required this.rating,
    required this.text,
    this.photoId,
    required this.createdAtMs,
  });

  final String id;
  final String authorName;
  final bool mine;
  final int rating;
  final String text;
  final String? photoId;
  final int createdAtMs;

  factory RecipeReview.fromJson(Map<String, dynamic> j) => RecipeReview(
        id: j['id'] as String,
        authorName: j['authorName'] as String? ?? 'Someone',
        mine: j['mine'] as bool? ?? false,
        rating: j['rating'] as int? ?? 0,
        text: j['text'] as String? ?? '',
        photoId: j['photoId'] as String?,
        createdAtMs: j['createdAtMs'] as int? ?? 0,
      );
}
