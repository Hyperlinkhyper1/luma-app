import 'package:drift/drift.dart';

// Both databases generate a `MindMaps` table and a `MindMapNode` row class,
// so the legacy side is always read through a prefix.
import '../../school/data/school_database.dart' as school_db;
import '../data/mind_map_database.dart';
import '../mind_map_repository.dart';

/// One-time move of the mind maps that used to live inside the School plugin
/// into the standalone Mind Map plugin.
///
/// School's tab has been retired, so without this the maps people already
/// made would be stranded behind a screen that no longer exists. The old rows
/// are copied, never deleted — if anything here goes wrong the originals are
/// still sitting in the School database.
class SchoolMindMapImport {
  const SchoolMindMapImport._();

  /// Every legacy node was created in this colour, so carrying it over would
  /// paint the whole map one shade. Nodes still wearing it fall back to the
  /// inherited branch colour instead.
  static const _legacyDefaultColor = 0xFF7C5AD9;

  static Future<int> run({
    required school_db.SchoolDatabase school,
    required MindMapRepository target,
  }) async {
    if (await target.schoolMapsImported) return 0;

    final maps = await school.select(school.mindMaps).get();
    if (maps.isEmpty) {
      // Nothing to carry over, but still record that the check has run so it
      // does not re-query the School database on every launch.
      await target.markSchoolMapsImported(0);
      return 0;
    }

    var imported = 0;
    for (final map in maps) {
      final legacyNodes = await (school.select(school.mindMapNodes)
            ..where((t) => t.mapId.equals(map.id)))
          .get();
      if (legacyNodes.isEmpty) continue;

      final mapId = await target.db.into(target.db.mindMaps).insert(
            MindMapsCompanion.insert(
              title: map.title,
              createdAt: Value(map.updatedAt),
              updatedAt: Value(map.updatedAt),
            ),
          );

      // The old canvas was freeform, so sibling order is recovered from where
      // the nodes actually sat: top to bottom, then left to right.
      final sanitized = _breakCycles(legacyNodes);
      final childrenOf = <int?, List<school_db.MindMapNode>>{};
      for (final node in sanitized) {
        childrenOf.putIfAbsent(node.parentId, () => []).add(node);
      }
      for (final list in childrenOf.values) {
        list.sort((a, b) {
          final byY = a.y.compareTo(b.y);
          return byY != 0 ? byY : a.x.compareTo(b.x);
        });
      }

      final newIds = <int, int>{};
      Future<void> walk(int? legacyParent) async {
        final level = childrenOf[legacyParent] ?? const <school_db.MindMapNode>[];
        for (var i = 0; i < level.length; i++) {
          final node = level[i];
          final id = await target.db.into(target.db.mindMapNodes).insert(
                MindMapNodesCompanion.insert(
                  mapId: mapId,
                  parentId: Value(legacyParent == null ? null : newIds[legacyParent]),
                  label: node.label,
                  color: Value(node.color == _legacyDefaultColor ? null : node.color),
                  sortIndex: Value(i),
                ),
              );
          newIds[node.id] = id;
          await walk(node.id);
        }
      }

      await walk(null);
      imported++;
    }

    await target.markSchoolMapsImported(imported);
    return imported;
  }

  /// The old schema never constrained `parentId`, so a map could contain a
  /// node pointing at a missing parent, at itself, or around a loop. Any of
  /// those leaves the branch unreachable from a root and therefore invisible,
  /// so they are promoted to roots instead.
  static List<school_db.MindMapNode> _breakCycles(List<school_db.MindMapNode> nodes) {
    final byId = {for (final n in nodes) n.id: n};
    return [
      for (final node in nodes)
        _hasValidAncestry(node, byId)
            ? node
            : node.copyWith(parentId: const Value(null)),
    ];
  }

  static bool _hasValidAncestry(
    school_db.MindMapNode node,
    Map<int, school_db.MindMapNode> byId,
  ) {
    var cursor = node;
    final seen = <int>{node.id};
    while (cursor.parentId != null) {
      final parent = byId[cursor.parentId];
      if (parent == null) return false;
      if (!seen.add(parent.id)) return false;
      cursor = parent;
    }
    return true;
  }
}
