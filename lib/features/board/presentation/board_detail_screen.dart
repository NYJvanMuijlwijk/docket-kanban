import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board/core/reorder_helpers.dart';
import 'package:kanban_board/features/board/domain/kanban_card.dart';
import 'package:kanban_board/features/board/domain/kanban_column.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:kanban_board/features/board/presentation/providers/card_providers.dart';
import 'package:kanban_board/features/board/presentation/providers/column_providers.dart';
import 'package:kanban_board/features/board/presentation/widgets/board_form_sheet.dart';
import 'package:kanban_board/features/board/presentation/widgets/card_form_sheet.dart';
import 'package:kanban_board/features/board/presentation/widgets/column_form_sheet.dart';

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
      await ref.read(boardListProvider.notifier).renameBoard(boardId, newName);
    }
  }

  Future<void> _addColumn(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final name = await ColumnFormSheet.show(context);
    if (name != null && context.mounted) {
      await ref.read(columnListProvider(boardId).notifier).createColumn(name);
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

        final columnsAsync = ref.watch(columnListProvider(boardId));

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
              return _BoardDragContent(
                boardId: boardId,
                columns: columns,
              );
            },
          ),
        );
      },
    );
  }
}

class _BoardDragContent extends ConsumerWidget {
  const _BoardDragContent({
    required this.boardId,
    required this.columns,
  });

  final String boardId;
  final List<KanbanColumn> columns;

  Future<void> _onItemReorder({
    required WidgetRef ref,
    required int oldItemIndex,
    required int oldListIndex,
    required int newItemIndex,
    required int newListIndex,
    required Map<String, List<KanbanCard>> columnCards,
  }) async {
    final sourceColumn = columns[oldListIndex];
    final targetColumn = columns[newListIndex];

    // Reject drops when source or target cards haven't loaded.
    if (!columnCards.containsKey(sourceColumn.id) ||
        !columnCards.containsKey(targetColumn.id)) {
      return;
    }

    if (oldListIndex == newListIndex) {
      // Same-column reorder.
      await ref
          .read(cardListProvider(sourceColumn.id).notifier)
          .reorderCard(oldItemIndex, newItemIndex);
    } else {
      // Cross-column move.
      final sourceCards = columnCards[sourceColumn.id] ?? [];
      final targetCards = columnCards[targetColumn.id] ?? [];
      if (oldItemIndex >= sourceCards.length) return;

      final card = sourceCards[oldItemIndex];
      final targetOrders = targetCards.map((c) => c.order).toList();
      final newOrder = computeOrderKeyAtInsert(targetOrders, newItemIndex);

      await ref
          .read(boardRepositoryProvider)
          .updateCard(
            card.copyWith(
              columnId: targetColumn.id,
              order: newOrder,
              updatedAt: DateTime.now(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Track each column's async state so we can render
    // loading/error/data per column.
    final columnStates = <String, AsyncValue<List<KanbanCard>>>{};
    final columnCards = <String, List<KanbanCard>>{};
    for (final column in columns) {
      final cardsAsync = ref.watch(cardListProvider(column.id));
      columnStates[column.id] = cardsAsync;
      final cards = cardsAsync.value;
      if (cards != null) {
        columnCards[column.id] = cards;
      }
    }

    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      minimum: EdgeInsets.only(
        bottom: bottomPadding > 0 ? 0 : 12,
      ),
      child: DragAndDropLists(
        children: [
          for (final column in columns)
            DragAndDropList(
              header: _ColumnHeader(
                column: column,
                cardCount: columnCards[column.id]?.length ?? 0,
                boardId: boardId,
              ),
              footer: columnStates[column.id] is AsyncData
                  ? _AddCardFooter(columnId: column.id)
                  : const SizedBox.shrink(),
              contentsWhenEmpty: _ColumnEmptyContent(
                state: columnStates[column.id]!,
              ),
              children: [
                for (final card in columnCards[column.id] ?? <KanbanCard>[])
                  DragAndDropItem(
                    child: _KanbanCardTile(
                      card: card,
                      columnId: column.id,
                    ),
                  ),
              ],
            ),
        ],
        onItemReorder:
            (
              oldItemIndex,
              oldListIndex,
              newItemIndex,
              newListIndex,
            ) async {
              await _onItemReorder(
                ref: ref,
                oldItemIndex: oldItemIndex,
                oldListIndex: oldListIndex,
                newItemIndex: newItemIndex,
                newListIndex: newListIndex,
                columnCards: columnCards,
              );
            },
        onListReorder: (oldListIndex, newListIndex) async {
          await ref
              .read(columnListProvider(boardId).notifier)
              .reorderColumn(oldListIndex, newListIndex);
        },
        axis: Axis.horizontal,
        listWidth: 300,
        listPadding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 12,
        ),
        listInnerDecoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        listDecorationWhileDragging: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        itemDecorationWhileDragging: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        lastItemTargetHeight: 24,
        lastListTargetSize: 0,
      ),
    );
  }
}

class _ColumnEmptyContent extends StatelessWidget {
  const _ColumnEmptyContent({required this.state});

  final AsyncValue<List<KanbanCard>> state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: switch (state) {
          AsyncLoading() => const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          AsyncError() => const Icon(Icons.error_outline),
          _ => const Text('No cards yet'),
        },
      ),
    );
  }
}

class _ColumnHeader extends ConsumerWidget {
  const _ColumnHeader({
    required this.column,
    required this.cardCount,
    required this.boardId,
  });

  final KanbanColumn column;
  final int cardCount;
  final String boardId;

  Future<void> _renameColumn(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final newName = await ColumnFormSheet.show(
      context,
      initialName: column.name,
    );
    if (newName != null && newName != column.name && context.mounted) {
      await ref
          .read(columnListProvider(boardId).notifier)
          .renameColumn(column.id, newName);
    }
  }

  Future<void> _deleteColumn(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final message = cardCount > 0
        ? "Delete '${column.name}' and its $cardCount "
              '${cardCount == 1 ? 'card' : 'cards'}?'
        : "Delete '${column.name}'?";

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Column'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref
          .read(columnListProvider(boardId).notifier)
          .deleteColumn(column.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 16,
        right: 4,
        top: 8,
        bottom: 4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              column.name,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'rename':
                  await _renameColumn(context, ref);
                case 'delete':
                  if (!context.mounted) return;
                  await _deleteColumn(context, ref);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'rename',
                child: Text('Rename'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KanbanCardTile extends ConsumerWidget {
  const _KanbanCardTile({
    required this.card,
    required this.columnId,
  });

  final KanbanCard card;
  final String columnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(card.title),
        subtitle: card.description.isNotEmpty
            ? Text(
                card.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        onTap: () async {
          final result = await CardDetailSheet.show(
            context,
            card: card,
          );
          if (!context.mounted) return;
          switch (result) {
            case CardEdited():
              await ref
                  .read(cardListProvider(columnId).notifier)
                  .updateCard(
                    id: card.id,
                    title: result.title,
                    description: result.description,
                  );
            case CardDeleted():
              await ref
                  .read(cardListProvider(columnId).notifier)
                  .deleteCard(card.id);
            case null:
              break;
          }
        },
      ),
    );
  }
}

class _AddCardFooter extends ConsumerWidget {
  const _AddCardFooter({required this.columnId});

  final String columnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextButton.icon(
        onPressed: () async {
          final result = await CardFormSheet.show(context);
          if (result != null && context.mounted) {
            await ref
                .read(cardListProvider(columnId).notifier)
                .createCard(
                  title: result.title,
                  description: result.description,
                );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Card'),
      ),
    );
  }
}
