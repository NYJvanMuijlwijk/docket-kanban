import 'package:kanban_board/features/board/domain/board.dart';
import 'package:kanban_board/features/board/domain/board_repository.dart';

/// Stub implementation — full CRUD in Slice 2.
class HiveBoardRepository implements BoardRepository {
  @override
  Future<List<Board>> getBoards() async => [];

  @override
  Future<Board> createBoard(Board board) async => board;

  @override
  Future<void> updateBoard(Board board) async {}

  @override
  Future<void> deleteBoard(String id) async {}

  @override
  Stream<List<Board>> watchBoards() => Stream.value([]);
}
