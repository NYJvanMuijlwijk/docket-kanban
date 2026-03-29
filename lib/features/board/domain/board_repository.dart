import 'package:kanban_board/features/board/domain/board.dart';
import 'package:kanban_board/features/board/domain/kanban_card.dart';
import 'package:kanban_board/features/board/domain/kanban_column.dart';

/// Repository abstraction for board persistence.
/// Implementations: HiveBoardRepository (local),
/// FirebaseBoardRepository (future).
abstract class BoardRepository {
  // Boards
  Future<List<Board>> getBoards();
  Future<Board?> getBoard(String id);
  Future<Board> createBoard(String name);
  Future<void> updateBoard(Board board);
  Future<void> deleteBoard(String id);
  /// Upsert a board — used by undo-delete to re-insert a snapshot.
  Future<void> putBoard(Board board);
  Stream<List<Board>> watchBoards();
  Stream<Board?> watchBoard(String id);

  // Columns
  Future<List<KanbanColumn>> getColumns(String boardId);
  Future<KanbanColumn?> getColumn(String id);
  Future<KanbanColumn> createColumn({
    required String boardId,
    required String name,
  });
  Future<void> updateColumn(KanbanColumn column);
  Future<void> deleteColumn(String id);
  /// Upsert a column — used by undo-delete to re-insert a snapshot.
  Future<void> putColumn(KanbanColumn column);
  Stream<List<KanbanColumn>> watchColumns(String boardId);

  // Cards
  Future<List<KanbanCard>> getCards(String columnId);
  Future<KanbanCard?> getCard(String id);
  Future<KanbanCard> createCard({
    required String columnId,
    required String title,
    String description = '',
  });
  Future<void> updateCard(KanbanCard card);
  Future<void> deleteCard(String id);
  /// Upsert a card — used by undo-delete to re-insert a snapshot.
  Future<void> putCard(KanbanCard card);
  Stream<List<KanbanCard>> watchCards(String columnId);

  void dispose();
}
