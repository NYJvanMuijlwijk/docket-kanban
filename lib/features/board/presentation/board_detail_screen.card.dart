part of 'board_detail_screen.dart';

/// Per-column card list. Watches only [cardListProvider] for its own column
/// (fixes Slice 4c — previously all columns re-watched together).
class _CardListView extends ConsumerWidget {
  const _CardListView({
    required this.column,
    required this.boardId,
    required this.autoScroll,
  });

  final KanbanColumn column;
  final String boardId;
  final AutoScrollHandler autoScroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardListProvider(column.id));

    return cardsAsync.when(
      loading: () => _ColumnEmptyContent(state: cardsAsync),
      error: (_, _) => _ColumnEmptyContent(state: cardsAsync),
      data: (cards) {
        if (cards.isEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InsertionGap(columnId: column.id, index: 0),
              _ColumnEmptyContent(state: cardsAsync),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              _InsertionGap(columnId: column.id, index: i),
              _DraggableCardSlot(
                card: cards[i],
                index: i,
                columnId: column.id,
                boardId: boardId,
                autoScroll: autoScroll,
              ),
            ],
            // Final gap after last card — allows dropping at end.
            _InsertionGap(columnId: column.id, index: cards.length),
          ],
        );
      },
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
              await guardMutation(
                context,
                () => ref
                    .read(cardListProvider(columnId).notifier)
                    .updateCard(
                      id: card.id,
                      title: result.title,
                      description: result.description,
                    ),
                'Failed to update card',
              );
            case CardDeleted():
              await guardMutation(
                context,
                () => ref
                    .read(cardListProvider(columnId).notifier)
                    .deleteCard(card.id),
                'Failed to delete card',
              );
            case null:
              break;
          }
        },
      ),
    );
  }
}
