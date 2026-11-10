import '../recipe_models.dart';

/// The supermarkets the chef can shop at — the same four the Groceries List
/// plugin searches. Brand names, so they are never translated.
const kMealChefStores = <String, String>{
  'jumbo': 'Jumbo',
  'ah': 'Albert Heijn',
  'lidl': 'Lidl',
  'hoogvliet': 'Hoogvliet',
};

/// Whether this device looks like it shops in the Netherlands, where the
/// groceries database has deals: the OS reports the NL region, or the app
/// speaks Dutch and the OS names no other Dutch-speaking region. Only then
/// does the chef ask about deals and stores.
bool mealChefShopsInNetherlands(String platformLocale, String appLanguage) {
  final match = RegExp(r'[_-]([A-Za-z]{2})\b').firstMatch(platformLocale);
  final region = match?.group(1)?.toUpperCase();
  if (region == 'NL') return true;
  if (appLanguage.split(RegExp('[_-]')).first != 'nl') return false;
  return region != 'BE' && region != 'SR';
}

/// What the household told the chef before it cooks anything.
class MealChefAnswers {
  const MealChefAnswers({
    required this.allergies,
    required this.people,
    required this.useDeals,
    required this.stores,
    required this.notes,
  });

  final String allergies;
  final int people;

  /// Null when the chef never asked (outside the Netherlands).
  final bool? useDeals;
  final List<String> stores;
  final String notes;
}

class ChefIngredient {
  const ChefIngredient({
    required this.name,
    required this.amount,
    required this.unit,
    required this.search,
    required this.dealId,
    required this.pantry,
  });

  final String name;
  final String amount;
  final String unit;

  /// A short supermarket search term for this ingredient.
  final String search;

  /// The id of the deal this ingredient was built around, or empty.
  final String dealId;

  /// Salt, oil and the like — left off the grocery list by default.
  final bool pantry;

  bool get fromDeal => dealId.isNotEmpty;

  Map<String, Object> toJson() => {
        'name': name,
        'amount': amount,
        'unit': unit,
        'search': search,
        'dealId': dealId,
        'pantry': pantry,
      };

  factory ChefIngredient.fromJson(Map<String, dynamic> j) => ChefIngredient(
        name: j['name'] as String? ?? '',
        amount: j['amount'] as String? ?? '',
        unit: j['unit'] as String? ?? '',
        search: j['search'] as String? ?? (j['name'] as String? ?? ''),
        dealId: j['dealId'] as String? ?? '',
        pantry: j['pantry'] as bool? ?? false,
      );
}

/// One meal the chef planned, as the server normalised it.
class ChefMeal {
  const ChefMeal({
    required this.title,
    required this.description,
    required this.category,
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.ingredients,
    required this.steps,
    required this.allergyNote,
    required this.message,
  });

  final String title;
  final String description;
  final String category;
  final int servings;
  final int prepMinutes;
  final int cookMinutes;
  final List<ChefIngredient> ingredients;
  final List<String> steps;
  final String allergyNote;
  final String message;

  int get totalMinutes => prepMinutes + cookMinutes;

  Map<String, Object> toJson() => {
        'title': title,
        'description': description,
        'category': category,
        'servings': servings,
        'prepMinutes': prepMinutes,
        'cookMinutes': cookMinutes,
        'ingredients': [for (final i in ingredients) i.toJson()],
        'steps': steps,
        'allergyNote': allergyNote,
        'message': message,
      };

  static ChefMeal? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final title = raw['title'];
    final ingredients = raw['ingredients'];
    final steps = raw['steps'];
    if (title is! String || title.isEmpty) return null;
    if (ingredients is! List || steps is! List) return null;
    final category = raw['category'] as String? ?? 'Dinner';
    return ChefMeal(
      title: title,
      description: raw['description'] as String? ?? '',
      category: kRecipeCategories.contains(category) ? category : 'Dinner',
      servings: (raw['servings'] as num?)?.toInt() ?? 2,
      prepMinutes: (raw['prepMinutes'] as num?)?.toInt() ?? 0,
      cookMinutes: (raw['cookMinutes'] as num?)?.toInt() ?? 0,
      ingredients: [
        for (final i in ingredients)
          if (i is Map<String, dynamic>) ChefIngredient.fromJson(i),
      ],
      steps: [
        for (final s in steps)
          if (s is String && s.trim().isNotEmpty) s.trim(),
      ],
      allergyNote: raw['allergyNote'] as String? ?? '',
      message: raw['message'] as String? ?? '',
    );
  }

  /// This meal as a private recipe, ready for the Recipe Book.
  LocalRecipe toLocalRecipe(String id, DateTime now) => LocalRecipe(
        id: id,
        title: title,
        description: [description, allergyNote]
            .where((s) => s.trim().isNotEmpty)
            .join('\n\n'),
        category: category,
        servings: servings,
        prepMinutes: prepMinutes,
        cookMinutes: cookMinutes,
        ingredients: [
          for (final i in ingredients)
            RecipeIngredient(
              name: i.name,
              amount: i.amount,
              unit: kRecipeUnits.contains(i.unit) ? i.unit : '',
            ),
        ],
        steps: steps,
        createdAt: now,
        updatedAt: now,
      );
}
