part of 'board_detail_screen.dart';

/// Per-column card list. Watches only [cardListProvider] for its own column
/// (fixes Slice 4c — previously all columns re-watched together).
class _CardListView extends ConsumerWidget {
  const _CardListView({
    required this.column,
    required this.columnIndex,
    required this.boardId,
    required this.autoScroll,
    required this.columnWidth,
  });

  final KanbanColumn column;
  final int columnIndex;
  final String boardId;
  final AutoScrollHandler autoScroll;
  final double columnWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardListProvider(column.id));

    void onRetry() => ref.invalidate(cardListProvider(column.id));

    return cardsAsync.when(
      loading: () => _ColumnEmptyContent(
        state: cardsAsync,
        onRetry: onRetry,
      ),
      error: (_, _) => _ColumnEmptyContent(
        state: cardsAsync,
        onRetry: onRetry,
      ),
      data: (cards) {
        if (cards.isEmpty) {
          return _InsertionGap(columnId: column.id, index: 0);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              _InsertionGap(
                key: ValueKey('gap-${column.id}-$i'),
                columnId: column.id,
                index: i,
              ),
              AnimatedListItem(
                key: ValueKey(cards[i].id),
                staggerIndex: i,
                child: _DraggableCardSlot(
                  card: cards[i],
                  index: i,
                  columnId: column.id,
                  columnIndex: columnIndex,
                  boardId: boardId,
                  autoScroll: autoScroll,
                  columnWidth: columnWidth,
                ),
              ),
            ],
            // Final gap after last card — allows dropping at end.
            _InsertionGap(
              key: ValueKey('gap-${column.id}-${cards.length}'),
              columnId: column.id,
              index: cards.length,
            ),
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
    required this.columnIndex,
  });

  final KanbanCard card;
  final String columnId;
  final int columnIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
        child: SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              // Left accent bar — column-colored for visual
              // association, especially during drag-and-drop.
              border: Border(
                left: BorderSide(
                  color: columnAccentColor(columnIndex),
                  width: 3,
                ),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (card.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      card.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
