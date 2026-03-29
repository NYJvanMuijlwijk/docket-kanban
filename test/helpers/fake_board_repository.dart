import 'dart:async';

import 'package:fractional_indexing/fractional_indexing.dart';
import 'package:kanban_board/core/mutation_exception.dart';
import 'package:kanban_board/core/seed_transformer.dart';
import 'package:kanban_board/features/board/domain/board.dart';
import 'package:kanban_board/features/board/domain/board_repository.dart';
import 'package:kanban_board/features/board/domain/kanban_card.dart';
import 'package:kanban_board/features/board/domain/kanban_column.dart';
import 'package:uuid/uuid.dart';

class FakeBoardRepository implements BoardRepository {
  FakeBoardRepository({
    List<Board>? initialBoards,
    List<KanbanColumn>? initialColumns,
    List<KanbanCard>? initialCards,
  }) {
    if (initialBoards != null) {
      for (final board in initialBoards) {
        _boards[board.id] = board;
      }
    }
    if (initialColumns != null) {
      for (final column in initialColumns) {
        _columns[column.id] = column;
      }
    }
    if (initialCards != null) {
      for (final card in initialCards) {
        _cards[card.id] = card;
      }
    }
  }

  static const _uuid = Uuid();

  final Map<String, Board> _boards = {};
  final Map<String, KanbanColumn> _columns = {};
  final Map<String, KanbanCard> _cards = {};
  final Map<String, String> _cardErrors = {};
  final Map<String, String> _columnErrors = {};
  final _boardController =
      StreamController<List<Board>>.broadcast();
  final _columnController =
      StreamController<List<KanbanColumn>>.broadcast();
  final _cardController =
      StreamController<List<KanbanCard>>.broadcast();
  String? _boardError;

  // ── Boards ──────────────────────────────────────────────────────

  @override
  Future<List<Board>> getBoards() async => _sortedBoards();

  @override
  Future<Board?> getBoard(String id) async => _boards[id];

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
    _boards[board.id] = board;
    _emitBoards();
    return board;
  }

  @override
  Future<void> updateBoard(Board board) async {
    if (!_boards.containsKey(board.id)) {
      throw const StaleDataException('Board was already deleted');
    }
    _boards[board.id] = board;
    _emitBoards();
  }

  @override
  Future<void> putBoard(Board board) async {
    _boards[board.id] = board;
    _emitBoards();
  }

  @override
  Future<void> deleteBoard(String id) async {
    if (!_boards.containsKey(id)) {
      throw const StaleDataException('Board was already deleted');
    }
    // Cascade: delete columns and their cards.
    final columnIds = _columns.values
        .where((c) => c.boardId == id)
        .map((c) => c.id)
        .toList();
    for (final colId in columnIds) {
      _cards.removeWhere((_, card) => card.columnId == colId);
      _columns.remove(colId);
    }
    _boards.remove(id);
    _emitBoards();
    _emitColumns();
    _emitCards();
  }

  @override
  Stream<List<Board>> watchBoards() {
    if (_boardError != null) {
      return Stream<List<Board>>.error(Exception(_boardError));
    }
    return _boardController.stream
        .transform(SeedTransformer<List<Board>>(_sortedBoards));
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
      _sortedColumns(boardId);

  @override
  Future<KanbanColumn?> getColumn(String id) async =>
      _columns[id];

  @override
  Future<KanbanColumn> createColumn({
    required String boardId,
    required String name,
  }) async {
    if (!_boards.containsKey(boardId)) {
      throw const StaleDataException('Board was already deleted');
    }
    final existing = _sortedColumns(boardId);
    if (existing.length >= 10) {
      throw const ValidationException('Board already has 10 columns');
    }

    final lastOrder =
        existing.isEmpty ? null : existing.last.order;
    final order =
        FractionalIndexer.generateKeyBetween(lastOrder, null)!;

    final now = DateTime.now();
    final column = KanbanColumn(
      id: _uuid.v4(),
      boardId: boardId,
      name: name,
      order: order,
      createdAt: now,
      updatedAt: now,
    );
    _columns[column.id] = column;
    _emitColumns();
    return column;
  }

  @override
  Future<void> updateColumn(KanbanColumn column) async {
    if (!_columns.containsKey(column.id)) {
      throw const StaleDataException('Column was already deleted');
    }
    _columns[column.id] = column;
    _emitColumns();
  }

  @override
  Future<void> putColumn(KanbanColumn column) async {
    _columns[column.id] = column;
    _emitColumns();
  }

  @override
  Future<void> deleteColumn(String id) async {
    if (!_columns.containsKey(id)) {
      throw const StaleDataException('Column was already deleted');
    }
    _cards.removeWhere((_, card) => card.columnId == id);
    _columns.remove(id);
    _emitColumns();
    _emitCards();
  }

  @override
  Stream<List<KanbanColumn>> watchColumns(String boardId) {
    if (_columnErrors.containsKey(boardId)) {
      return Stream<List<KanbanColumn>>.error(
        Exception(_columnErrors[boardId]),
      );
    }
    return _columnController.stream
        .transform(
          SeedTransformer<List<KanbanColumn>>(
            () => _sortedColumns(boardId),
          ),
        )
        .map(
          (all) => all
              .where((c) => c.boardId == boardId)
              .toList(),
        );
  }

  // ── Cards ───────────────────────────────────────────────────────

  @override
  Future<List<KanbanCard>> getCards(String columnId) async =>
      _sortedCards(columnId);

  @override
  Future<KanbanCard?> getCard(String id) async => _cards[id];

  @override
  Future<KanbanCard> createCard({
    required String columnId,
    required String title,
    String description = '',
  }) async {
    if (!_columns.containsKey(columnId)) {
      throw const StaleDataException('Column was already deleted');
    }
    final existing = _sortedCards(columnId);
    if (existing.length >= 100) {
      throw const ValidationException('Column already has 100 cards');
    }

    final lastOrder =
        existing.isEmpty ? null : existing.last.order;
    final order =
        FractionalIndexer.generateKeyBetween(lastOrder, null)!;

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
    _cards[card.id] = card;
    _emitCards();
    return card;
  }

  @override
  Future<void> updateCard(KanbanCard card) async {
    if (!_cards.containsKey(card.id)) {
      throw const StaleDataException('Card was already deleted');
    }
    _cards[card.id] = card;
    _emitCards();
  }

  @override
  Future<void> putCard(KanbanCard card) async {
    _cards[card.id] = card;
    _emitCards();
  }

  @override
  Future<void> deleteCard(String id) async {
    if (!_cards.containsKey(id)) {
      throw const StaleDataException('Card was already deleted');
    }
    _cards.remove(id);
    _emitCards();
  }

  @override
  Stream<List<KanbanCard>> watchCards(String columnId) {
    if (_cardErrors.containsKey(columnId)) {
      return Stream<List<KanbanCard>>.error(
        Exception(_cardErrors[columnId]),
      );
    }
    return _cardController.stream
        .transform(
          SeedTransformer<List<KanbanCard>>(
            () => _sortedCards(columnId),
          ),
        )
        .map(
          (all) => all
              .where((c) => c.columnId == columnId)
              .toList(),
        );
  }

  // ── Lifecycle ───────────────────────────────────────────────────

  @override
  void dispose() {
    unawaited(_boardController.close());
    unawaited(_columnController.close());
    unawaited(_cardController.close());
  }

  // ── Test helpers ──────────────────────────────────────────────

  /// Makes [watchBoards] emit an error instead of data.
  // ignore: use_setters_to_change_properties
  void setBoardError(String message) {
    _boardError = message;
  }

  /// Makes [watchColumns] emit an error for [boardId] instead of data.
  void setColumnError(String boardId, String message) {
    _columnErrors[boardId] = message;
  }

  /// Makes [watchCards] emit an error for [columnId] instead of data.
  void setCardError(String columnId, String message) {
    _cardErrors[columnId] = message;
  }

  // ── Private helpers ─────────────────────────────────────────────

  List<Board> _sortedBoards() {
    return _boards.values.toList()
      ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
  }

  List<KanbanColumn> _sortedColumns(String boardId) {
    return _columns.values
        .where((c) => c.boardId == boardId)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  List<KanbanCard> _sortedCards(String columnId) {
    return _cards.values
        .where((c) => c.columnId == columnId)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  void _emitBoards() {
    _boardController.add(_sortedBoards());
  }

  void _emitColumns() {
    _columnController.add(
      _columns.values.toList()
        ..sort((a, b) => a.order.compareTo(b.order)),
    );
  }

  void _emitCards() {
    _cardController.add(
      _cards.values.toList()
        ..sort((a, b) => a.order.compareTo(b.order)),
    );
  }
}
