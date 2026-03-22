import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board/features/board/domain/kanban_column.dart';
import 'package:kanban_board/features/board/presentation/providers/card_providers.dart';
import 'package:kanban_board/features/board/presentation/providers/column_providers.dart';
import 'package:kanban_board/features/board/presentation/widgets/card_form_sheet.dart';
import 'package:kanban_board/features/board/presentation/widgets/column_form_sheet.dart';

class KanbanColumnWidget extends ConsumerWidget {
  const KanbanColumnWidget({
    required this.column,
    super.key,
  });

  final KanbanColumn column;

  Future<void> _addCard(BuildContext context, WidgetRef ref) async {
    final result = await CardFormSheet.show(context);
    if (result != null && context.mounted) {
      await ref.read(cardListProvider(column.id).notifier).createCard(
            title: result.title,
            description: result.description,
          );
    }
  }

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
          .read(columnListProvider(column.boardId).notifier)
          .renameColumn(column.id, newName);
    }
  }

  Future<void> _deleteColumn(
    BuildContext context,
    WidgetRef ref,
    int cardCount,
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
          .read(columnListProvider(column.boardId).notifier)
          .deleteColumn(column.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardListProvider(column.id));

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        child: Column(
          children: [
            // ── Column header ──
            Padding(
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
                      style:
                          Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'rename':
                          await _renameColumn(context, ref);
                        case 'delete':
                          final cardCount =
                              cardsAsync.value?.length ?? 0;
                          if (!context.mounted) return;
                          await _deleteColumn(
                            context,
                            ref,
                            cardCount,
                          );
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
            ),
            const Divider(height: 1),

            // ── Card list ──
            Expanded(
              child: cardsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, _) => Center(
                  child: Text('Error: $error'),
                ),
                data: (cards) {
                  if (cards.isEmpty) {
                    return const Center(
                      child: Text('No cards yet'),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return Card(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHigh,
                        child: ListTile(
                          title: Text(card.title),
                          subtitle: card.description.isNotEmpty
                              ? Text(
                                  card.description,
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () async {
                            final result =
                                await CardDetailSheet.show(
                              context,
                              card: card,
                            );
                            if (!context.mounted) return;
                            switch (result) {
                              case CardEdited():
                                await ref
                                    .read(
                                      cardListProvider(
                                        column.id,
                                      ).notifier,
                                    )
                                    .updateCard(
                                      id: card.id,
                                      title: result.title,
                                      description:
                                          result.description,
                                    );
                              case CardDeleted():
                                await ref
                                    .read(
                                      cardListProvider(
                                        column.id,
                                      ).notifier,
                                    )
                                    .deleteCard(card.id);
                              case null:
                                break;
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // ── Add card button ──
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton.icon(
                onPressed: () => _addCard(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add Card'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
