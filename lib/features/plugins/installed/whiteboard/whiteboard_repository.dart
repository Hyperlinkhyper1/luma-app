import 'package:drift/drift.dart';

import '../../../../storage/storage_guard.dart';
import 'data/whiteboard_database.dart';
import 'model/whiteboard_element.dart';

class WhiteboardRepository {
  WhiteboardRepository(this._db);

  final WhiteboardDatabase _db;

  Stream<List<Board>> watchBoards() {
    final query = _db.select(_db.boards)
      ..orderBy([(b) => OrderingTerm.desc(b.updatedAt)]);
    return query.watch();
  }

  Stream<Board?> watchBoard(int boardId) {
    final query = _db.select(_db.boards)..where((b) => b.id.equals(boardId));
    return query.watchSingleOrNull();
  }

  /// How many elements each board holds, for the library cards.
  Stream<Map<int, int>> watchElementCounts() {
    final count = _db.boardElements.id.count();
    final query = _db.selectOnly(_db.boardElements)
      ..addColumns([_db.boardElements.boardId, count])
      ..groupBy([_db.boardElements.boardId]);
    return query.watch().map((rows) => {
          for (final row in rows)
            row.read(_db.boardElements.boardId)!: row.read(count) ?? 0,
        });
  }

  Future<int> createBoard(String title) async {
    final id = await _db.into(_db.boards).insert(
          BoardsCompanion.insert(title: title),
        );
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  Future<void> renameBoard(int boardId, String title) async {
    await (_db.update(_db.boards)..where((b) => b.id.equals(boardId))).write(
      BoardsCompanion(title: Value(title), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> deleteBoard(int boardId) async {
    // The cascade in the schema only fires with foreign keys on, which the
    // migration strategy enables — but deleting the children first keeps this
    // correct even on a connection that was opened without it.
    await (_db.delete(_db.boardElements)
          ..where((e) => e.boardId.equals(boardId)))
        .go();
    await (_db.delete(_db.boards)..where((b) => b.id.equals(boardId))).go();
    StorageGuard.instance.scheduleRefresh();
  }

  Stream<List<WhiteboardElement>> watchElements(int boardId) {
    final query = _db.select(_db.boardElements)
      ..where((e) => e.boardId.equals(boardId))
      ..orderBy([
        (e) => OrderingTerm.asc(e.z),
        (e) => OrderingTerm.asc(e.id),
      ]);
    return query.watch().map(
          (rows) => rows.map(_toElement).toList(growable: false),
        );
  }

  Future<List<WhiteboardElement>> elementsOf(int boardId) async {
    final query = _db.select(_db.boardElements)
      ..where((e) => e.boardId.equals(boardId))
      ..orderBy([
        (e) => OrderingTerm.asc(e.z),
        (e) => OrderingTerm.asc(e.id),
      ]);
    final rows = await query.get();
    return rows.map(_toElement).toList(growable: false);
  }

  /// Inserts [element] on top of the stack and returns it with its new id.
  ///
  /// Undo hands the element straight back here, so the returned copy is what
  /// the caller must keep: the row it gets back has a different id than the
  /// one it was deleted under.
  Future<WhiteboardElement> addElement(
    int boardId,
    WhiteboardElement element,
  ) async {
    final results = await addElements(boardId, [element]);
    return results.single;
  }

  Future<List<WhiteboardElement>> addElements(
    int boardId,
    List<WhiteboardElement> elements,
  ) async {
    if (elements.isEmpty) return const [];
    final added = <WhiteboardElement>[];
    await _db.transaction(() async {
      var z = await _nextZ(boardId);
      for (final element in elements) {
        final id = await _db.into(_db.boardElements).insert(
              BoardElementsCompanion.insert(
                boardId: boardId,
                kind: element.kind.name,
                data: element.encode(),
                z: Value(z),
              ),
            );
        added.add(element.copyWith(id: id, boardId: boardId, z: z));
        z++;
      }
      await _touch(boardId);
    });
    StorageGuard.instance.scheduleRefresh();
    return added;
  }

  Future<void> updateElement(WhiteboardElement element) async {
    await (_db.update(_db.boardElements)
          ..where((e) => e.id.equals(element.id)))
        .write(BoardElementsCompanion(data: Value(element.encode())));
    await _touch(element.boardId);
  }

  Future<void> deleteElements(int boardId, List<int> ids) async {
    if (ids.isEmpty) return;
    await (_db.delete(_db.boardElements)..where((e) => e.id.isIn(ids))).go();
    await _touch(boardId);
    StorageGuard.instance.scheduleRefresh();
  }

  Future<void> clearBoard(int boardId) async {
    await (_db.delete(_db.boardElements)
          ..where((e) => e.boardId.equals(boardId)))
        .go();
    await _touch(boardId);
    StorageGuard.instance.scheduleRefresh();
  }

  Future<int> _nextZ(int boardId) async {
    final top = _db.boardElements.z.max();
    final query = _db.selectOnly(_db.boardElements)
      ..addColumns([top])
      ..where(_db.boardElements.boardId.equals(boardId));
    final row = await query.getSingleOrNull();
    return (row?.read(top) ?? -1) + 1;
  }

  Future<void> _touch(int boardId) async {
    await (_db.update(_db.boards)..where((b) => b.id.equals(boardId)))
        .write(BoardsCompanion(updatedAt: Value(DateTime.now())));
  }

  WhiteboardElement _toElement(BoardElement row) => WhiteboardElement.decode(
        id: row.id,
        boardId: row.boardId,
        kind: row.kind,
        data: row.data,
        z: row.z,
      );
}
