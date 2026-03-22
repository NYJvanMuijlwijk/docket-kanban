import 'package:kanban_board/features/board/domain/kanban_column.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'column_providers.g.dart';

@riverpod
class ColumnList extends _$ColumnList {
  Future<KanbanColumn> createColumn(String name) {
    final repository = ref.read(boardRepositoryProvider);
    return repository.createColumn(boardId: boardId, name: name);
  }

  Future<void> renameColumn(String id, String newName) async {
    final repository = ref.read(boardRepositoryProvider);
    final column = await repository.getColumn(id);
    if (column == null) {
      throw ArgumentError('Column not found: $id');
    }
    await repository.updateColumn(
      column.copyWith(name: newName, updatedAt: DateTime.now()),
    );
  }

  Future<void> deleteColumn(String id) {
    final repository = ref.read(boardRepositoryProvider);
    return repository.deleteColumn(id);
  }

  @override
  Stream<List<KanbanColumn>> build(String boardId) {
    final repository = ref.watch(boardRepositoryProvider);
    return repository.watchColumns(boardId);
  }
}
