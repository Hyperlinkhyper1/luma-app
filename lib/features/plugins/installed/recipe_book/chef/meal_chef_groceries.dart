import '../../groceries/groceries_api.dart';
import '../../groceries/groceries_repository.dart';
import 'meal_chef_models.dart';

/// Deals fetched per chosen store. Four stores at this size stay within the
/// server's cap on deals per request.
const kMealChefDealsPerStore = 40;

/// What [buildMealChefGroceryList] did: the new list (null when nothing at
/// all could be matched), how many products went on it, and which
/// ingredients had no product in the chosen stores.
class MealChefGroceryResult {
  const MealChefGroceryResult({
    required this.listId,
    required this.added,
    required this.missing,
  });

  final int? listId;
  final int added;
  final List<String> missing;
}

/// The deals on offer in [stores] right now, for the chef to cook around.
/// Never throws: without deals the chef simply plans an ordinary meal.
Future<List<RemoteProduct>> fetchMealChefDeals(
    GroceriesApi api, List<String> stores) async {
  final deals = <RemoteProduct>[];
  for (final store in stores) {
    try {
      deals.addAll(await api.search(
        marketSlugs: [store],
        onlyDeals: true,
        limit: kMealChefDealsPerStore,
      ));
    } catch (_) {}
  }
  return deals;
}

/// The product to buy for one ingredient out of a search's [results]: the
/// best-ranked deal when the household cooks from deals, otherwise the
/// best-ranked product with a known price.
RemoteProduct? pickMealChefProduct(List<RemoteProduct> results,
    {required bool preferDeals}) {
  if (results.isEmpty) return null;
  if (preferDeals) {
    for (final p in results) {
      if (p.isDiscounted && p.price != null) return p;
    }
  }
  for (final p in results) {
    if (p.price != null) return p;
  }
  return results.first;
}

/// Puts [meal]'s ingredients on a new Groceries List list named after it.
/// Ingredients built around a deal get that exact product; the rest are
/// searched in [stores] (all stores when empty). Pantry staples are skipped.
Future<MealChefGroceryResult> buildMealChefGroceryList({
  required GroceriesRepository repository,
  required GroceriesApi api,
  required ChefMeal meal,
  required List<String> stores,
  required List<RemoteProduct> deals,
  required bool preferDeals,
}) async {
  final dealsById = {for (final d in deals) d.id: d};
  final wanted = meal.ingredients.where((i) => !i.pantry).toList();
  final picks = List<RemoteProduct?>.filled(wanted.length, null);

  Future<void> match(int index) async {
    final ingredient = wanted[index];
    final deal = dealsById[ingredient.dealId];
    if (deal != null) {
      picks[index] = deal;
      return;
    }
    try {
      final results = await api.search(
        query: ingredient.search,
        marketSlugs: stores.isEmpty ? null : stores,
        limit: 8,
      );
      picks[index] = pickMealChefProduct(results, preferDeals: preferDeals);
    } catch (_) {}
  }

  const batch = 4;
  for (var start = 0; start < wanted.length; start += batch) {
    await Future.wait([
      for (var i = start; i < wanted.length && i < start + batch; i++) match(i),
    ]);
  }

  final missing = [
    for (var i = 0; i < wanted.length; i++)
      if (picks[i] == null) wanted[i].name,
  ];
  final found = picks.whereType<RemoteProduct>().toList();
  if (found.isEmpty) {
    return MealChefGroceryResult(listId: null, added: 0, missing: missing);
  }
  final name = meal.title.length > 120 ? meal.title.substring(0, 120) : meal.title;
  final listId = await repository.createList(name);
  final seen = <String>{};
  var added = 0;
  for (final product in found) {
    if (!seen.add('${product.market.slug}:${product.id}')) continue;
    await repository.addProduct(listId, product);
    added++;
  }
  return MealChefGroceryResult(listId: listId, added: added, missing: missing);
}
