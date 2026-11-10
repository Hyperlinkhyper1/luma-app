import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/groceries/data/groceries_database.dart';
import 'package:luma/features/plugins/installed/groceries/groceries_api.dart';
import 'package:luma/features/plugins/installed/groceries/groceries_repository.dart';
import 'package:luma/features/plugins/installed/recipe_book/chef/meal_chef_api.dart';
import 'package:luma/features/plugins/installed/recipe_book/chef/meal_chef_groceries.dart';
import 'package:luma/features/plugins/installed/recipe_book/chef/meal_chef_models.dart';
import 'package:luma/storage/storage_guard.dart';

RemoteProduct _product(
  String id,
  String name, {
  String market = 'jumbo',
  double? price = 1.99,
  bool deal = false,
}) =>
    RemoteProduct(
      id: id,
      name: name,
      brand: null,
      category: null,
      imageUrl: null,
      market: RemoteMarket(id: 1, slug: market, name: market),
      price: price,
      oldPrice: deal ? 2.99 : null,
      isDiscounted: deal,
      quantity: '500 g',
      discountPercentage: null,
      discountText: deal ? '2e halve prijs' : null,
    );

ChefMeal _meal() => ChefMeal.tryParse({
      'title': 'Kip met groenten',
      'description': 'Snel.',
      'category': 'Dinner',
      'servings': 3,
      'prepMinutes': 10,
      'cookMinutes': 20,
      'ingredients': [
        {
          'name': 'Kipfilet',
          'amount': '450',
          'unit': 'g',
          'search': 'kipfilet',
          'dealId': 'deal-1',
          'pantry': false,
        },
        {
          'name': 'Broccoli',
          'amount': '1',
          'unit': 'piece',
          'search': 'broccoli',
          'dealId': '',
          'pantry': false,
        },
        {
          'name': 'Saffraan',
          'amount': '',
          'unit': 'pinch',
          'search': 'saffraan',
          'dealId': '',
          'pantry': false,
        },
        {
          'name': 'Zout',
          'amount': '',
          'unit': 'to taste',
          'search': 'zout',
          'dealId': '',
          'pantry': true,
        },
      ],
      'steps': ['Bak de kip.', 'Kook de broccoli.'],
      'allergyNote': 'Geen pinda gebruikt.',
      'message': 'Eet smakelijk!',
    })!;

class _FakeGroceriesApi extends GroceriesApi {
  _FakeGroceriesApi(this.results);

  final Map<String, List<RemoteProduct>> results;
  final searches = <String?>[];

  @override
  Future<List<RemoteProduct>> search({
    String? query,
    List<String>? marketSlugs,
    String? category,
    bool onlyDeals = false,
    ProductSort sort = ProductSort.relevance,
    int limit = 40,
    int offset = 0,
  }) async {
    searches.add(query);
    return results[query] ?? const [];
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    StorageGuardService.instance = StorageGuardService();
  });

  group('Netherlands check', () {
    test('the NL region always counts', () {
      expect(mealChefShopsInNetherlands('nl_NL', 'nl'), isTrue);
      expect(mealChefShopsInNetherlands('en_NL', 'en'), isTrue);
      expect(mealChefShopsInNetherlands('en-NL', 'en'), isTrue);
    });

    test('Dutch in the app counts unless the OS names Belgium or Suriname',
        () {
      expect(mealChefShopsInNetherlands('en_US', 'nl'), isTrue);
      expect(mealChefShopsInNetherlands('', 'nl'), isTrue);
      expect(mealChefShopsInNetherlands('nl_BE', 'nl'), isFalse);
      expect(mealChefShopsInNetherlands('nl_SR', 'nl'), isFalse);
    });

    test('anywhere else does not', () {
      expect(mealChefShopsInNetherlands('en_US', 'en'), isFalse);
      expect(mealChefShopsInNetherlands('fr_FR', 'fr'), isFalse);
      expect(mealChefShopsInNetherlands('', 'en'), isFalse);
    });
  });

  test('a planned meal saves as a private recipe with known units', () {
    final recipe = _meal().toLocalRecipe('chef_1', DateTime(2026, 11, 10));
    expect(recipe.title, 'Kip met groenten');
    expect(recipe.servings, 3);
    expect(recipe.ingredients.first.unit, 'g');
    expect(recipe.steps, hasLength(2));
    expect(recipe.description, contains('Geen pinda gebruikt.'));
  });

  test('deals travel only when the household asked for them', () {
    const base = MealChefAnswers(
      allergies: '',
      people: 2,
      useDeals: true,
      stores: ['jumbo'],
      notes: '',
    );
    final deals = [_product('deal-1', 'Kipfilet', deal: true)];
    final withDeals = MealChefApi.requestBody(
        answers: base, language: 'nl', deals: deals);
    final dealJson = (withDeals['deals'] as List).single as Map;
    expect(dealJson['id'], 'deal-1');
    expect(dealJson['store'], 'jumbo');
    expect(dealJson['price'], '€1.99');
    expect(dealJson['discount'], '2e halve prijs');

    const abroad = MealChefAnswers(
      allergies: 'nuts',
      people: 4,
      useDeals: null,
      stores: [],
      notes: '',
    );
    final body = MealChefApi.requestBody(
        answers: abroad, language: 'en', deals: deals);
    expect(body.containsKey('deals'), isFalse);
    expect(body.containsKey('useDeals'), isFalse);
    expect(body['people'], 4);
  });

  test('changing a meal sends it back with the feedback', () {
    const answers = MealChefAnswers(
        allergies: '', people: 2, useDeals: false, stores: [], notes: '');
    final body = MealChefApi.requestBody(
      answers: answers,
      language: 'en',
      previous: _meal(),
      feedback: ['no chicken'],
    );
    expect((body['previous'] as Map)['title'], 'Kip met groenten');
    expect(body['feedback'], ['no chicken']);
  });

  test('product picking prefers deals only when asked', () {
    final results = [
      _product('a', 'Gewoon'),
      _product('b', 'Aanbieding', deal: true),
    ];
    expect(pickMealChefProduct(results, preferDeals: true)!.id, 'b');
    expect(pickMealChefProduct(results, preferDeals: false)!.id, 'a');
    expect(
        pickMealChefProduct([_product('x', 'Geen prijs', price: null), ...results],
                preferDeals: false)!
            .id,
        'a');
    expect(pickMealChefProduct(const [], preferDeals: true), isNull);
  });

  test('the grocery list uses the exact deal, skips pantry and reports misses',
      () async {
    final db = GroceriesDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = GroceriesRepository(db);
    final api = _FakeGroceriesApi({
      'broccoli': [_product('broc', 'Broccoli', market: 'ah')],
    });
    final result = await buildMealChefGroceryList(
      repository: repository,
      api: api,
      meal: _meal(),
      stores: const ['jumbo', 'ah'],
      deals: [_product('deal-1', 'Kipfilet 500 g', deal: true)],
      preferDeals: true,
    );
    expect(result.listId, isNotNull);
    expect(result.added, 2);
    expect(result.missing, ['Saffraan']);
    expect(api.searches, unorderedEquals(['broccoli', 'saffraan']));

    final lists = await repository.watchLists().first;
    expect(lists.single.name, 'Kip met groenten');
    final items = await repository.watchItems(result.listId!).first;
    expect(items.map((i) => i.name), ['Kipfilet 500 g', 'Broccoli']);
  });

  test('no list is made when nothing could be found', () async {
    final db = GroceriesDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = GroceriesRepository(db);
    final result = await buildMealChefGroceryList(
      repository: repository,
      api: _FakeGroceriesApi(const {}),
      meal: _meal(),
      stores: const [],
      deals: const [],
      preferDeals: false,
    );
    expect(result.listId, isNull);
    expect(await repository.watchLists().first, isEmpty);
  });
}
