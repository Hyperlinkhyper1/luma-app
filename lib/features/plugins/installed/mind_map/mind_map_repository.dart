import 'package:drift/drift.dart';

import '../../../../storage/storage_guard.dart';
import 'data/mind_map_database.dart';
import 'io/mind_map_outline.dart';
import 'layout/mind_map_layout.dart';

/// Everything that was removed from a map by one action, kept whole so the
/// exact rows (ids included) can be put back. Reusing the ids is what lets a
/// restored subtree reattach to its old parent and keep its own children.
class MindMapDeletion {
  const MindMapDeletion({required this.rows, required this.description});

  final List<MindMapNode> rows;
  final String description;
}

class MindMapRepository {
  MindMapRepository(this._db);

  final MindMapDatabase _db;

  MindMapDatabase get db => _db;

  static const _schoolImportKey = 'schoolMindMapsImported';

  // ---------------------------------------------------------------- maps

  Stream<List<MindMap>> watchMaps() {
    final query = _db.select(_db.mindMaps)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch();
  }

  Stream<MindMap?> watchMap(int id) {
    final query = _db.select(_db.mindMaps)..where((t) => t.id.equals(id));
    return query.watchSingleOrNull();
  }

  /// Creates a map together with its root node, so opening a brand new map
  /// lands the user on something they can immediately type into instead of
  /// an empty canvas with a "add your first node" dialog.
  Future<int> createMap(String title, {MindMapDirection direction = MindMapDirection.right}) async {
    StorageGuard.instance.ensureWithinLimit();
    final mapId = await _db.into(_db.mindMaps).insert(
          MindMapsCompanion.insert(
            title: title,
            direction: Value(direction.index),
          ),
        );
    await _db.into(_db.mindMapNodes).insert(
          MindMapNodesCompanion.insert(mapId: mapId, label: title),
        );
    StorageGuard.instance.scheduleRefresh();
    return mapId;
  }

  Future<void> renameMap(int id, String title) => (_db.update(_db.mindMaps)
        ..where((t) => t.id.equals(id)))
      .write(MindMapsCompanion(title: Value(title), updatedAt: Value(DateTime.now())));

  Future<void> setDirection(int id, MindMapDirection direction) =>
      (_db.update(_db.mindMaps)..where((t) => t.id.equals(id))).write(
        MindMapsCompanion(
          direction: Value(direction.index),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> deleteMap(int id) async {
    await (_db.delete(_db.mindMapNodes)..where((t) => t.mapId.equals(id))).go();
    await (_db.delete(_db.mindMaps)..where((t) => t.id.equals(id))).go();
    StorageGuard.instance.scheduleRefresh();
  }

  /// Node totals for the map list, keyed by map id.
  ///
  /// Counted in SQL rather than by loading every node, so the list stays
  /// cheap no matter how big the maps get.
  Stream<Map<int, int>> watchNodeCounts() {
    return _db
        .customSelect(
          'SELECT map_id, COUNT(*) AS node_count FROM mind_map_nodes GROUP BY map_id',
          readsFrom: {_db.mindMapNodes},
        )
        .watch()
        .map((rows) => {
              for (final row in rows)
                row.read<int>('map_id'): row.read<int>('node_count'),
            });
  }

  Future<int> nodeCount(int mapId) async {
    final rows = await (_db.select(_db.mindMapNodes)
          ..where((t) => t.mapId.equals(mapId)))
        .get();
    return rows.length;
  }

  // --------------------------------------------------------------- nodes

  Stream<List<MindMapNode>> watchNodes(int mapId) {
    final query = _db.select(_db.mindMapNodes)
      ..where((t) => t.mapId.equals(mapId))
      ..orderBy([(t) => OrderingTerm.asc(t.sortIndex), (t) => OrderingTerm.asc(t.id)]);
    return query.watch();
  }

  Future<List<MindMapNode>> nodes(int mapId) {
    final query = _db.select(_db.mindMapNodes)..where((t) => t.mapId.equals(mapId));
    return query.get();
  }

  /// Appends a child under [parentId] and returns its id so the caller can
  /// drop straight into editing it.
  Future<int> addChild({
    required int mapId,
    required int? parentId,
    String label = '',
  }) async {
    StorageGuard.instance.ensureWithinLimit();
    final siblings = await _siblingsOf(mapId, parentId);
    final id = await _db.into(_db.mindMapNodes).insert(
          MindMapNodesCompanion.insert(
            mapId: mapId,
            parentId: Value(parentId),
            label: label,
            sortIndex: Value(siblings.isEmpty ? 0 : siblings.last.sortIndex + 1),
          ),
        );
    await _touch(mapId);
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  /// Inserts a sibling directly after [afterId], shifting everything below it
  /// down so the new node lands where the user expects rather than at the end.
  Future<int> addSiblingAfter({
    required int mapId,
    required int afterId,
    String label = '',
  }) async {
    final after = await _node(afterId);
    if (after == null) return addChild(mapId: mapId, parentId: null, label: label);

    StorageGuard.instance.ensureWithinLimit();
    final siblings = await _siblingsOf(mapId, after.parentId);
    for (final sibling in siblings) {
      if (sibling.sortIndex > after.sortIndex) {
        await (_db.update(_db.mindMapNodes)..where((t) => t.id.equals(sibling.id)))
            .write(MindMapNodesCompanion(sortIndex: Value(sibling.sortIndex + 1)));
      }
    }
    final id = await _db.into(_db.mindMapNodes).insert(
          MindMapNodesCompanion.insert(
            mapId: mapId,
            parentId: Value(after.parentId),
            label: label,
            sortIndex: Value(after.sortIndex + 1),
          ),
        );
    await _touch(mapId);
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  Future<void> updateNode(
    int id, {
    String? label,
    String? note,
    String? link,
    int? color,
    bool clearNote = false,
    bool clearLink = false,
    bool clearColor = false,
  }) async {
    final node = await _node(id);
    if (node == null) return;
    await (_db.update(_db.mindMapNodes)..where((t) => t.id.equals(id))).write(
      MindMapNodesCompanion(
        label: label == null ? const Value.absent() : Value(label),
        note: clearNote ? const Value(null) : (note == null ? const Value.absent() : Value(note)),
        link: clearLink ? const Value(null) : (link == null ? const Value.absent() : Value(link)),
        color:
            clearColor ? const Value(null) : (color == null ? const Value.absent() : Value(color)),
      ),
    );
    await _touch(node.mapId);
  }

  Future<void> setCollapsed(int id, bool collapsed) =>
      (_db.update(_db.mindMapNodes)..where((t) => t.id.equals(id)))
          .write(MindMapNodesCompanion(collapsed: Value(collapsed)));

  /// Moves [id] under [newParentId].
  ///
  /// Refuses to move a node into its own subtree — otherwise the branch
  /// would detach from the root and vanish from the layout.
  Future<bool> reparent(int id, int? newParentId) async {
    final node = await _node(id);
    if (node == null) return false;
    if (newParentId == id) return false;
    if (newParentId != null) {
      final all = await nodes(node.mapId);
      if (_isDescendant(all, ancestorId: id, candidateId: newParentId)) return false;
    }
    final siblings = await _siblingsOf(node.mapId, newParentId);
    await (_db.update(_db.mindMapNodes)..where((t) => t.id.equals(id))).write(
      MindMapNodesCompanion(
        parentId: Value(newParentId),
        sortIndex: Value(siblings.isEmpty
            ? 0
            : siblings.where((s) => s.id != id).fold<int>(-1, (m, s) => s.sortIndex > m ? s.sortIndex : m) + 1),
      ),
    );
    await _touch(node.mapId);
    return true;
  }

  /// Nudges a node up or down among its siblings.
  Future<void> move(int id, int delta) async {
    final node = await _node(id);
    if (node == null) return;
    final siblings = await _siblingsOf(node.mapId, node.parentId);
    final index = siblings.indexWhere((s) => s.id == id);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= siblings.length) return;

    final reordered = [...siblings];
    reordered.removeAt(index);
    reordered.insert(target, node);
    for (var i = 0; i < reordered.length; i++) {
      await (_db.update(_db.mindMapNodes)..where((t) => t.id.equals(reordered[i].id)))
          .write(MindMapNodesCompanion(sortIndex: Value(i)));
    }
    await _touch(node.mapId);
  }

  /// Deletes a node and everything under it, returning the removed rows so
  /// the action can be undone.
  Future<MindMapDeletion?> deleteSubtree(int id) async {
    final node = await _node(id);
    if (node == null) return null;
    final all = await nodes(node.mapId);
    final doomed = _subtreeOf(all, id);
    for (final row in doomed) {
      await (_db.delete(_db.mindMapNodes)..where((t) => t.id.equals(row.id))).go();
    }
    await _touch(node.mapId);
    StorageGuard.instance.scheduleRefresh();
    final label = node.label.trim().isEmpty ? 'node' : '"${node.label.trim()}"';
    return MindMapDeletion(
      rows: doomed,
      description: doomed.length == 1 ? 'Deleted $label' : 'Deleted $label and ${doomed.length - 1} below it',
    );
  }

  /// Puts back rows removed by [deleteSubtree], ids intact.
  Future<void> restore(MindMapDeletion deletion) async {
    if (deletion.rows.isEmpty) return;
    StorageGuard.instance.ensureWithinLimit();
    for (final row in deletion.rows) {
      await _db.into(_db.mindMapNodes).insert(row, mode: InsertMode.insertOrReplace);
    }
    await _touch(deletion.rows.first.mapId);
    StorageGuard.instance.scheduleRefresh();
  }

  // ------------------------------------------------------------ outlines

  /// Grafts a parsed outline under [parentId]. Used by both the paste-an-
  /// outline import and the AI expansion sheet.
  Future<int> insertOutline({
    required int mapId,
    required int? parentId,
    required List<OutlineNode> roots,
  }) async {
    StorageGuard.instance.ensureWithinLimit();
    var inserted = 0;
    Future<void> walk(int? parent, List<OutlineNode> level) async {
      final siblings = await _siblingsOf(mapId, parent);
      var next = siblings.isEmpty ? 0 : siblings.last.sortIndex + 1;
      for (final node in level) {
        final id = await _db.into(_db.mindMapNodes).insert(
              MindMapNodesCompanion.insert(
                mapId: mapId,
                parentId: Value(parent),
                label: node.label,
                note: Value(node.note),
                link: Value(node.link),
                sortIndex: Value(next++),
              ),
            );
        inserted++;
        await walk(id, node.children);
      }
    }

    await walk(parentId, roots);
    await _touch(mapId);
    StorageGuard.instance.scheduleRefresh();
    return inserted;
  }

  /// Rebuilds the map as an [OutlineNode] forest for export.
  Future<List<OutlineNode>> toOutline(int mapId) async {
    final all = await nodes(mapId);
    final children = <int?, List<MindMapNode>>{};
    final ids = {for (final n in all) n.id};
    for (final n in all) {
      final parent = n.parentId != null && ids.contains(n.parentId) ? n.parentId : null;
      children.putIfAbsent(parent, () => []).add(n);
    }
    for (final list in children.values) {
      list.sort((a, b) {
        final byIndex = a.sortIndex.compareTo(b.sortIndex);
        return byIndex != 0 ? byIndex : a.id.compareTo(b.id);
      });
    }

    OutlineNode build(MindMapNode row) => OutlineNode(
          label: row.label,
          note: row.note,
          link: row.link,
          children: [for (final c in children[row.id] ?? const <MindMapNode>[]) build(c)],
        );

    return [for (final root in children[null] ?? const <MindMapNode>[]) build(root)];
  }

  // ------------------------------------------------------------- metadata

  Future<bool> hasFlag(String key) async {
    final row = await (_db.select(_db.mindMapMeta)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> setFlag(String key, String value) => _db
      .into(_db.mindMapMeta)
      .insert(MindMapMetaCompanion.insert(key: key, value: value), mode: InsertMode.insertOrReplace);

  Future<bool> get schoolMapsImported => hasFlag(_schoolImportKey);

  Future<void> markSchoolMapsImported(int count) =>
      setFlag(_schoolImportKey, '${DateTime.now().toIso8601String()} ($count)');

  // -------------------------------------------------------------- helpers

  Future<MindMapNode?> _node(int id) =>
      (_db.select(_db.mindMapNodes)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<MindMapNode>> _siblingsOf(int mapId, int? parentId) async {
    final query = _db.select(_db.mindMapNodes)
      ..where((t) => t.mapId.equals(mapId))
      ..where((t) => parentId == null ? t.parentId.isNull() : t.parentId.equals(parentId))
      ..orderBy([(t) => OrderingTerm.asc(t.sortIndex), (t) => OrderingTerm.asc(t.id)]);
    return query.get();
  }

  Future<void> _touch(int mapId) => (_db.update(_db.mindMaps)
        ..where((t) => t.id.equals(mapId)))
      .write(MindMapsCompanion(updatedAt: Value(DateTime.now())));

  static List<MindMapNode> _subtreeOf(List<MindMapNode> all, int rootId) {
    final byParent = <int?, List<MindMapNode>>{};
    for (final n in all) {
      byParent.putIfAbsent(n.parentId, () => []).add(n);
    }
    final byId = {for (final n in all) n.id: n};
    final result = <MindMapNode>[];
    final seen = <int>{};
    void walk(int id) {
      if (!seen.add(id)) return;
      final row = byId[id];
      if (row == null) return;
      result.add(row);
      for (final child in byParent[id] ?? const <MindMapNode>[]) {
        walk(child.id);
      }
    }

    walk(rootId);
    return result;
  }

  static bool _isDescendant(
    List<MindMapNode> all, {
    required int ancestorId,
    required int candidateId,
  }) {
    final byId = {for (final n in all) n.id: n};
    var cursor = byId[candidateId];
    final seen = <int>{};
    while (cursor != null && seen.add(cursor.id)) {
      if (cursor.parentId == ancestorId) return true;
      cursor = cursor.parentId == null ? null : byId[cursor.parentId];
    }
    return false;
  }
}
