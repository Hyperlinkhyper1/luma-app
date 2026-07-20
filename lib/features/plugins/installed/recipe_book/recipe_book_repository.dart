import 'dart:convert';
import 'package:drift/drift.dart';

import '../../../../storage/storage_guard.dart';
import 'data/recipe_book_database.dart';

class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    required this.amount,
    required this.unit,
  });

  final String name;
  final String amount;
  final String unit;

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'unit': unit,
      };

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        name: json['name'] as String? ?? '',
        amount: json['amount'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
      );
}

class RecipeRecord {
  const RecipeRecord({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.ingredients,
    required this.steps,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String? description;
  final String category;
  final int servings;
  final int prepMinutes;
  final int cookMinutes;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalMinutes => prepMinutes + cookMinutes;
}

class RecipeBookRepository {
  RecipeBookRepository(this._db);

  final RecipeBookDatabase _db;

  Stream<List<RecipeRecord>> watchAll() {
    final query = _db.select(_db.recipes)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch().map(
          (rows) => rows.map(_toRecord).toList(growable: false),
        );
  }

  Stream<List<RecipeRecord>> watchByCategory(String category) {
    final query = _db.select(_db.recipes)
      ..where((t) => t.category.equals(category))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch().map(
          (rows) => rows.map(_toRecord).toList(growable: false),
        );
  }

  Future<void> save({
    int? id,
    required String title,
    String? description,
    required String category,
    required int servings,
    required int prepMinutes,
    required int cookMinutes,
    required List<RecipeIngredient> ingredients,
    required List<String> steps,
    required List<String> tags,
  }) async {
    final now = DateTime.now();
    final companion = RecipesCompanion(
      title: Value(title),
      description: Value(description),
      category: Value(category),
      servings: Value(servings),
      prepMinutes: Value(prepMinutes),
      cookMinutes: Value(cookMinutes),
      ingredients: Value(jsonEncode(ingredients.map((i) => i.toJson()).toList())),
      steps: Value(jsonEncode(steps)),
      tags: Value(tags.isEmpty ? null : jsonEncode(tags)),
      updatedAt: Value(now),
    );

    if (id != null) {
      await (_db.update(_db.recipes)..where((t) => t.id.equals(id)))
          .write(companion);
    } else {
      StorageGuard.instance.ensureWithinLimit();
      await _db.into(_db.recipes).insert(
            companion.copyWith(createdAt: Value(now)),
          );
      StorageGuard.instance.scheduleRefresh();
    }
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.recipes)..where((t) => t.id.equals(id))).go();
  }

  RecipeRecord _toRecord(Recipe row) {
    List<RecipeIngredient> ingredients = [];
    try {
      final decoded = jsonDecode(row.ingredients) as List<dynamic>;
      ingredients = decoded
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}

    List<String> steps = [];
    try {
      final decoded = jsonDecode(row.steps) as List<dynamic>;
      steps = decoded.cast<String>();
    } catch (_) {}

    List<String> tags = [];
    if (row.tags != null) {
      try {
        final decoded = jsonDecode(row.tags!) as List<dynamic>;
        tags = decoded.cast<String>();
      } catch (_) {}
    }

    return RecipeRecord(
      id: row.id,
      title: row.title,
      description: row.description,
      category: row.category,
      servings: row.servings,
      prepMinutes: row.prepMinutes,
      cookMinutes: row.cookMinutes,
      ingredients: ingredients,
      steps: steps,
      tags: tags,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
