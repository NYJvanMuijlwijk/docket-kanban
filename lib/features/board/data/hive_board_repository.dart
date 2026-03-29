import 'dart:async';

import 'package:fractional_indexing/fractional_indexing.dart';
import 'package:hive/hive.dart';
import 'package:kanban_board/core/mutation_exception.dart';
import 'package:kanban_board/core/seed_transformer.dart';
import 'package:kanban_board/features/board/domain/board.dart';
import 'package:kanban_board/features/board/domain/board_repository.dart';
import 'package:kanban_board/features/board/domain/kanban_card.dart';
import 'package:kanban_board/features/board/domain/kanban_column.dart';
import 'package:uuid/uuid.dart';

class HiveBoardRepository implements BoardRepository {
  HiveBoardRepository(this._boardBox, this._columnBox, this._cardBox) {
    _boardSub = _boardBox.watch().listen((_) => _emitBoards());
    _columnSub = _columnBox.watch().listen((_) => _emitColumns());
    _cardSub = _cardBox.watch().listen((_) => _emitCards());
  }

  static const boxName = 'boards';
  static const columnBoxName = 'columns';
  static const cardBoxName = 'cards';
  static const maxCardsPerColumn = 100;

  final Box<Map<dynamic, dynamic>> _boardBox;
  final Box<Map<dynamic, dynamic>> _columnBox;
  final Box<Map<dynamic, dynamic>> _cardBox;
  final _uuid = const Uuid();
  final _boardController = StreamController<List<Board>>.broadcast();
  final _columnController = StreamController<List<KanbanColumn>>.broadcast();
  final _cardController = StreamController<List<KanbanCard>>.broadcast();
  late final StreamSubscription<BoxEvent> _boardSub;
  late final StreamSubscription<BoxEvent> _columnSub;
  late final StreamSubscription<BoxEvent> _cardSub;

  // ── Boards ──────────────────────────────────────────────────────

  @override
  Future<List<Board>> getBoards() async => _readAllBoards();

  @override
  Future<Board?> getBoard(String id) async {
    final raw = _boardBox.get(id);
    if (raw == null) return null;
    return Board.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<Board> createBoard(String name) async {
    final now = DateTime.now();
    final board = Board(
      id: _uuid.v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
      lastUsedAt: now,
    );
    await _putBoard(board);
    return board;
  }

  @override
  Future<void> updateBoard(Board board) async {
    if (!_boardBox.containsKey(board.id)) {
      throw const StaleDataException('Board was already deleted');
    }
    await _putBoard(board);
  }

  @override
  Future<void> putBoard(Board board) async {
    await _putBoard(board);
  }

  @override
  Future<void> deleteBoard(String id) async {
    if (!_boardBox.containsKey(id)) {
      throw const StaleDataException('Board was already deleted');
    }
    // Cascade: delete all columns (and their cards) for this board.
    final columns = _readColumnsByBoard(id);
    for (final column in columns) {
      await _deleteCardsForColumn(column.id);
      await _deleteColumnBox(column.id);
    }
    await _deleteBoardBox(id);
  }

  @override
  Stream<List<Board>> watchBoards() {
    return _boardController.stream.transform(
      SeedTransformer<List<Board>>(_readAllBoards),
    );
  }

  @override
  Stream<Board?> watchBoard(String id) {
    return watchBoards().map(
      (boards) {
        for (final board in boards) {
          if (board.id == id) return board;
        }
        return null;
      },
    );
  }

  // ── Columns ─────────────────────────────────────────────────────

  @override
  Future<List<KanbanColumn>> getColumns(String boardId) async =>
      _readColumnsByBoard(boardId);

  @override
  Future<KanbanColumn?> getColumn(String id) async {
    final raw = _columnBox.get(id);
    if (raw == null) return null;
    return KanbanColumn.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<KanbanColumn> createColumn({
    required String boardId,
    required String name,
  }) async {
    if (!_boardBox.containsKey(boardId)) {
      throw const StaleDataException('Board was already deleted');
    }
    final existing = _readColumnsByBoard(boardId);
    if (existing.length >= maxColumnsPerBoard) {
      throw const ValidationException(
        'Board already has $maxColumnsPerBoard columns',
      );
    }

    final lastOrder = existing.isEmpty ? null : existing.last.order;
    final order = FractionalIndexer.generateKeyBetween(lastOrder, null)!;

    final now = DateTime.now();
    final column = KanbanColumn(
      id: _uuid.v4(),
      boardId: boardId,
      name: name,
      order: order,
      createdAt: now,
      updatedAt: now,
    );
    await _putColumn(column);
    return column;
  }

  @override
  Future<void> updateColumn(KanbanColumn column) async {
    if (!_columnBox.containsKey(column.id)) {
      throw const StaleDataException('Column was already deleted');
    }
    await _putColumn(column);
  }

  @override
  Future<void> putColumn(KanbanColumn column) async {
    await _putColumn(column);
  }

  @override
  Future<void> deleteColumn(String id) async {
    if (!_columnBox.containsKey(id)) {
      throw const StaleDataException('Column was already deleted');
    }
    await _deleteCardsForColumn(id);
    await _deleteColumnBox(id);
  }

  @override
  Stream<List<KanbanColumn>> watchColumns(String boardId) {
    return _columnController.stream
        .transform(
          SeedTransformer<List<KanbanColumn>>(
            () => _readColumnsByBoard(boardId),
          ),
        )
        .map(
          (all) => all.where((c) => c.boardId == boardId).toList(),
        );
  }

  // ── Cards ───────────────────────────────────────────────────────

  @override
  Future<List<KanbanCard>> getCards(String columnId) async =>
      _readCardsByColumn(columnId);

  @override
  Future<KanbanCard?> getCard(String id) async {
    final raw = _cardBox.get(id);
    if (raw == null) return null;
    return KanbanCard.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<KanbanCard> createCard({
    required String columnId,
    required String title,
    String description = '',
  }) async {
    if (!_columnBox.containsKey(columnId)) {
      throw const StaleDataException('Column was already deleted');
    }
    final existing = _readCardsByColumn(columnId);
    if (existing.length >= maxCardsPerColumn) {
      throw const ValidationException(
        'Column already has $maxCardsPerColumn cards',
      );
    }

    final lastOrder = existing.isEmpty ? null : existing.last.order;
    final order = FractionalIndexer.generateKeyBetween(lastOrder, null)!;

    final now = DateTime.now();
    final card = KanbanCard(
      id: _uuid.v4(),
      columnId: columnId,
      title: title,
      description: description,
      order: order,
      createdAt: now,
      updatedAt: now,
    );
    await _putCard(card);
    return card;
  }

  @override
  Future<void> updateCard(KanbanCard card) async {
    if (!_cardBox.containsKey(card.id)) {
      throw const StaleDataException('Card was already deleted');
    }
    await _putCard(card);
  }

  @override
  Future<void> putCard(KanbanCard card) async {
    await _putCard(card);
  }

  @override
  Future<void> deleteCard(String id) async {
    if (!_cardBox.containsKey(id)) {
      throw const StaleDataException('Card was already deleted');
    }
    await _deleteCardBox(id);
  }

  @override
  Stream<List<KanbanCard>> watchCards(String columnId) {
    return _cardController.stream
        .transform(
          SeedTransformer<List<KanbanCard>>(
            () => _readCardsByColumn(columnId),
          ),
        )
        .map(
          (all) => all.where((c) => c.columnId == columnId).toList(),
        );
  }

  // ── Lifecycle ───────────────────────────────────────────────────

  @override
  void dispose() {
    unawaited(_boardSub.cancel());
    unawaited(_columnSub.cancel());
    unawaited(_cardSub.cancel());
    unawaited(_boardController.close());
    unawaited(_columnController.close());
    unawaited(_cardController.close());
  }

  // ── Storage wrappers ─────────────────────────────────────────────
  // Wrap Hive I/O so callers see StorageException, not raw HiveError.

  Future<void> _putBoard(Board board) async {
    try {
      await _boardBox.put(board.id, board.toJson());
    } on Exception {
      throw const StorageException("Couldn't save board");
    }
  }

  Future<void> _deleteBoardBox(String id) async {
    try {
      await _boardBox.delete(id);
    } on Exception {
      throw const StorageException("Couldn't remove board");
    }
  }

  Future<void> _putColumn(KanbanColumn column) async {
    try {
      await _columnBox.put(column.id, column.toJson());
    } on Exception {
      throw const StorageException("Couldn't save column");
    }
  }

  Future<void> _deleteColumnBox(String id) async {
    try {
      await _columnBox.delete(id);
    } on Exception {
      throw const StorageException("Couldn't remove column");
    }
  }

  Future<void> _putCard(KanbanCard card) async {
    try {
      await _cardBox.put(card.id, card.toJson());
    } on Exception {
      throw const StorageException("Couldn't save card");
    }
  }

  Future<void> _deleteCardBox(String id) async {
    try {
      await _cardBox.delete(id);
    } on Exception {
      throw const StorageException("Couldn't remove card");
    }
  }

  // ── Private helpers ─────────────────────────────────────────────

  List<Board> _readAllBoards() {
    return _boardBox.values
        .map(
          (raw) => Board.fromJson(Map<String, dynamic>.from(raw)),
        )
        .toList()
      ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
  }

  List<KanbanColumn> _readColumnsByBoard(String boardId) {
    return _columnBox.values
        .map(
          (raw) => KanbanColumn.fromJson(Map<String, dynamic>.from(raw)),
        )
        .where((c) => c.boardId == boardId)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  List<KanbanCard> _readCardsByColumn(String columnId) {
    return _cardBox.values
        .map(
          (raw) => KanbanCard.fromJson(Map<String, dynamic>.from(raw)),
        )
        .where((c) => c.columnId == columnId)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> _deleteCardsForColumn(String columnId) async {
    final cardIds = _cardBox.values
        .map(
          (raw) => KanbanCard.fromJson(Map<String, dynamic>.from(raw)),
        )
        .where((c) => c.columnId == columnId)
        .map((c) => c.id)
        .toList();
    try {
      await _cardBox.deleteAll(cardIds);
    } on Exception {
      throw const StorageException("Couldn't remove cards");
    }
  }

  List<KanbanColumn> _readAllColumns() {
    return _columnBox.values
        .map(
          (raw) => KanbanColumn.fromJson(Map<String, dynamic>.from(raw)),
        )
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  List<KanbanCard> _readAllCards() {
    return _cardBox.values
        .map(
          (raw) => KanbanCard.fromJson(Map<String, dynamic>.from(raw)),
        )
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  void _emitBoards() {
    _boardController.add(_readAllBoards());
  }

  void _emitColumns() {
    _columnController.add(_readAllColumns());
  }

  void _emitCards() {
    _cardController.add(_readAllCards());
  }
}
