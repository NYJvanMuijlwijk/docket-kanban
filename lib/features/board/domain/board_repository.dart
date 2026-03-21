import 'package:kanban_board/features/board/domain/board.dart';

/// Repository abstraction for board persistence.
/// Implementations: HiveBoardRepository (local),
/// FirebaseBoardRepository (future).
abstract class BoardRepository {
  Future<List<Board>> getBoards();
  Future<Board> createBoard(Board board);
  Future<void> updateBoard(Board board);
  Future<void> deleteBoard(String id);
  Stream<List<Board>> watchBoards();
}
