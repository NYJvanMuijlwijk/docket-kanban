import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board/features/board/domain/board.dart';
import 'package:kanban_board/features/board/domain/board_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'board_providers.g.dart';

/// Manual provider for repository injection. Override in tests
/// and for future Firebase swap.
// Not using codegen — needs to be manually overridable.
final Provider<BoardRepository> boardRepositoryProvider =
    Provider<BoardRepository>(
  (ref) => throw UnimplementedError(
    'boardRepositoryProvider must be overridden with a real implementation',
  ),
);

@riverpod
class BoardList extends _$BoardList {
  @override
  Stream<List<Board>> build() {
    final repository = ref.watch(boardRepositoryProvider);
    ref.onDispose(repository.dispose);
    return repository.watchBoards();
  }

  Future<Board> createBoard(String name) {
    final repository = ref.read(boardRepositoryProvider);
    return repository.createBoard(name);
  }

  Future<void> deleteBoard(String id) {
    final repository = ref.read(boardRepositoryProvider);
    return repository.deleteBoard(id);
  }

  Future<void> renameBoard(String id, String newName) async {
    final repository = ref.read(boardRepositoryProvider);
    final board = await repository.getBoard(id);
    if (board == null) {
      throw ArgumentError('Board not found: $id');
    }
    await repository.updateBoard(
      board.copyWith(name: newName, updatedAt: DateTime.now()),
    );
  }
}

@riverpod
Future<Board?> board(Ref ref, String id) {
  final repository = ref.watch(boardRepositoryProvider);
  return repository.getBoard(id);
}
