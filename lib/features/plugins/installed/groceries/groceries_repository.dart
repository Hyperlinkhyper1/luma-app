import 'package:drift/drift.dart';

import '../../../../storage/storage_guard.dart';
import 'data/groceries_database.dart';
import 'groceries_api.dart';

/// A shopping list with its item count and running total pre-aggregated, so
/// the overview page doesn't need to load every item to show a summary.
class GroceryListRecord {
  const GroceryListRecord({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.itemCount,
    required this.total,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int itemCount;
  final double total;
}

/// One product on a list. Name/brand/image/price are snapshotted at add
/// time, so totals stay meaningful even if the remote catalog entry changes.
class GroceryListItemRecord {
  const GroceryListItemRecord({
    required this.id,
    required this.listId,
    required this.productId,
    required this.market,
    required this.marketName,
    required this.name,
    required this.brand,
    required this.imageUrl,
    required this.category,
    required this.price,
    required this.quantity,
    required this.addedAt,
  });

  final int id;
  final int listId;
  final String? productId;
  final String market;
  final String marketName;
  final String name;
  final String? brand;
  final String? imageUrl;
  final String? category;
  final double? price;
  final int quantity;
  final DateTime addedAt;

  double get lineTotal => (price ?? 0) * quantity;
}

class GroceriesRepository {
  GroceriesRepository(this._db);

  final GroceriesDatabase _db;

  // ── Lists ────────────────────────────────────────────────────────────

  Stream<List<GroceryListRecord>> watchLists() {
    final query = _db.customSelect(
      'SELECT gl.id AS id, gl.name AS name, gl.created_at AS created_at, '
      'gl.updated_at AS updated_at, COUNT(gli.id) AS item_count, '
      'COALESCE(SUM(gli.price * gli.quantity), 0) AS total '
      'FROM grocery_lists gl '
      'LEFT JOIN grocery_list_items gli ON gli.list_id = gl.id '
      'GROUP BY gl.id '
      'ORDER BY gl.updated_at DESC',
      readsFrom: {_db.groceryLists, _db.groceryListItems},
    );
    return query.watch().map(
          (rows) => rows
              .map((row) => GroceryListRecord(
                    id: row.read<int>('id'),
                    name: row.read<String>('name'),
                    createdAt: row.read<DateTime>('created_at'),
                    updatedAt: row.read<DateTime>('updated_at'),
                    itemCount: row.read<int>('item_count'),
                    total: row.read<double>('total'),
                  ))
              .toList(growable: false),
        );
  }

  /// Streams just the list's name, for a detail page's title bar (stays
  /// correct if the list is renamed while open).
  Stream<String?> watchListName(int id) {
    final query = _db.select(_db.groceryLists)..where((t) => t.id.equals(id));
    return query.watchSingleOrNull().map((row) => row?.name);
  }

  Future<int> createList(String name) async {
    StorageGuard.instance.ensureWithinLimit();
    final id = await _db.into(_db.groceryLists).insert(
          GroceryListsCompanion.insert(name: name),
        );
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  Future<void> renameList(int id, String name) {
    return (_db.update(_db.groceryLists)..where((t) => t.id.equals(id))).write(
      GroceryListsCompanion(
        name: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteList(int id) async {
    // No DB-level cascade — remove the list's items first.
    await (_db.delete(_db.groceryListItems)..where((t) => t.listId.equals(id))).go();
    await (_db.delete(_db.groceryLists)..where((t) => t.id.equals(id))).go();
  }

  // ── Items ────────────────────────────────────────────────────────────

  Stream<List<GroceryListItemRecord>> watchItems(int listId) {
    final query = _db.select(_db.groceryListItems)
      ..where((t) => t.listId.equals(listId))
      ..orderBy([(t) => OrderingTerm.asc(t.addedAt)]);
    return query.watch().map(
          (rows) => rows.map(_toItemRecord).toList(growable: false),
        );
  }

  Future<void> addProduct(int listId, RemoteProduct product,
      {int quantity = 1}) async {
    StorageGuard.instance.ensureWithinLimit();
    await _db.into(_db.groceryListItems).insert(
          GroceryListItemsCompanion.insert(
            listId: listId,
            productId: Value(product.id),
            market: product.market.slug,
            marketName: product.market.name,
            name: product.name,
            brand: Value(product.brand),
            imageUrl: Value(product.imageUrl),
            category: Value(product.category),
            price: Value(product.price),
            quantity: Value(quantity),
          ),
        );
    await _touchList(listId);
    StorageGuard.instance.scheduleRefresh();
  }

  Future<void> setQuantity(GroceryListItemRecord item, int quantity) async {
    if (quantity <= 0) {
      await removeItem(item);
      return;
    }
    await (_db.update(_db.groceryListItems)..where((t) => t.id.equals(item.id)))
        .write(GroceryListItemsCompanion(quantity: Value(quantity)));
    await _touchList(item.listId);
  }

  Future<void> removeItem(GroceryListItemRecord item) async {
    await (_db.delete(_db.groceryListItems)..where((t) => t.id.equals(item.id))).go();
    await _touchList(item.listId);
  }

  Future<void> _touchList(int listId) {
    return (_db.update(_db.groceryLists)..where((t) => t.id.equals(listId)))
        .write(GroceryListsCompanion(updatedAt: Value(DateTime.now())));
  }

  GroceryListItemRecord _toItemRecord(GroceryListItem row) =>
      GroceryListItemRecord(
        id: row.id,
        listId: row.listId,
        productId: row.productId,
        market: row.market,
        marketName: row.marketName,
        name: row.name,
        brand: row.brand,
        imageUrl: row.imageUrl,
        category: row.category,
        price: row.price,
        quantity: row.quantity,
        addedAt: row.addedAt,
      );
}
