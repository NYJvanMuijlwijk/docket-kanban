import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:kanban_board/features/board/presentation/providers/column_providers.dart';
import 'package:kanban_board/features/board/presentation/widgets/board_form_sheet.dart';
import 'package:kanban_board/features/board/presentation/widgets/column_form_sheet.dart';
import 'package:kanban_board/features/board/presentation/widgets/kanban_column_widget.dart';

class BoardDetailScreen extends ConsumerWidget {
  const BoardDetailScreen({required this.boardId, super.key});

  final String boardId;

  Future<void> _renameBoard(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    final newName = await BoardFormSheet.show(
      context,
      initialName: currentName,
    );
    if (newName != null && newName != currentName && context.mounted) {
      await ref
          .read(boardListProvider.notifier)
          .renameBoard(boardId, newName);
    }
  }

  Future<void> _addColumn(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final name = await ColumnFormSheet.show(context);
    if (name != null && context.mounted) {
      await ref
          .read(columnListProvider(boardId).notifier)
          .createColumn(name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(boardProvider(boardId));

    return boardAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $error')),
      ),
      data: (board) {
        if (board == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Board not found')),
          );
        }

        final columnsAsync =
            ref.watch(columnListProvider(boardId));

        return Scaffold(
          appBar: AppBar(
            title: Text(board.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'rename') {
                    await _renameBoard(context, ref, board.name);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename'),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addColumn(context, ref),
            child: const Icon(Icons.add),
          ),
          body: columnsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => Center(
              child: Text('Error: $error'),
            ),
            data: (columns) {
              if (columns.isEmpty) {
                return const Center(
                  child: Text(
                    'No columns yet. Tap + to add one.',
                  ),
                );
              }
              return SafeArea(
                top: false,
                left: false,
                right: false,
                minimum: const EdgeInsets.only(bottom: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  itemCount: columns.length,
                  itemBuilder: (context, index) {
                    return KanbanColumnWidget(
                      column: columns[index],
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
