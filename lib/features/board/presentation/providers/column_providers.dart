import 'package:kanban_board/core/reorder_helpers.dart';
import 'package:kanban_board/features/board/domain/kanban_column.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'column_providers.g.dart';

@riverpod
class ColumnList extends _$ColumnList {
  @override
  Stream<List<KanbanColumn>> build(String boardId) {
    final repository = ref.watch(boardRepositoryProvider);
    return repository.watchColumns(boardId).map(
      (columns) => columns
        ..sort((a, b) => a.order.compareTo(b.order)),
    );
  }

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

  Future<void> reorderColumn(int oldIndex, int newIndex) async {
    final columns = state.value;
    if (columns == null) return;

    final sortedOrders =
        columns.map((c) => c.order).toList();
    final newOrder =
        computeOrderKeyBetween(sortedOrders, oldIndex, newIndex);
    if (newOrder == null) return;

    final repository = ref.read(boardRepositoryProvider);
    await repository.updateColumn(
      columns[oldIndex]
          .copyWith(order: newOrder, updatedAt: DateTime.now()),
    );
  }
}
