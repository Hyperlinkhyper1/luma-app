import 'package:drift/drift.dart';

import 'data/bulletin_board_database.dart';

class BoardItemRecord {
  const BoardItemRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.color,
    required this.posX,
    required this.posY,
    required this.width,
    required this.height,
    required this.pinned,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String? title;
  final String content;
  final int color;
  final double posX;
  final double posY;
  final double width;
  final double height;
  final bool pinned;
  final DateTime createdAt;

  BoardItemRecord copyWith({
    String? title,
    String? content,
    int? color,
    double? posX,
    double? posY,
    double? width,
    double? height,
    bool? pinned,
  }) {
    return BoardItemRecord(
      id: id,
      type: type,
      title: title ?? this.title,
      content: content ?? this.content,
      color: color ?? this.color,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      width: width ?? this.width,
      height: height ?? this.height,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt,
    );
  }
}

class BulletinBoardRepository {
  BulletinBoardRepository(this._db);

  final BulletinBoardDatabase _db;

  Stream<List<BoardItemRecord>> watchAll() {
    return _db.select(_db.boardItems).watch().map(
          (rows) => rows.map(_toRecord).toList(growable: false),
        );
  }

  Future<void> add({
    required String type,
    String? title,
    required String content,
    int color = 0xFFFFFFFF,
    double posX = 0.0,
    double posY = 0.0,
    double width = 200.0,
    double height = 200.0,
    bool pinned = false,
  }) {
    return _db.into(_db.boardItems).insert(
          BoardItemsCompanion.insert(
            type: type,
            title: Value(title),
            content: content,
            color: Value(color),
            posX: Value(posX),
            posY: Value(posY),
            width: Value(width),
            height: Value(height),
            pinned: Value(pinned),
          ),
        );
  }

  Future<void> updateItem(BoardItemRecord record) {
    return (_db.update(_db.boardItems)..where((t) => t.id.equals(record.id)))
        .write(
      BoardItemsCompanion(
        title: Value(record.title),
        content: Value(record.content),
        color: Value(record.color),
        posX: Value(record.posX),
        posY: Value(record.posY),
        width: Value(record.width),
        height: Value(record.height),
        pinned: Value(record.pinned),
      ),
    );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.boardItems)..where((t) => t.id.equals(id))).go();
  }

  Future<void> togglePin(int id, bool currentPinned) {
    return (_db.update(_db.boardItems)..where((t) => t.id.equals(id)))
        .write(BoardItemsCompanion(pinned: Value(!currentPinned)));
  }

  BoardItemRecord _toRecord(BoardItem row) => BoardItemRecord(
        id: row.id,
        type: row.type,
        title: row.title,
        content: row.content,
        color: row.color,
        posX: row.posX,
        posY: row.posY,
        width: row.width,
        height: row.height,
        pinned: row.pinned,
        createdAt: row.createdAt,
      );
}
