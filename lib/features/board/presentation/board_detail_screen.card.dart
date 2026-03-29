part of 'board_detail_screen.dart';

/// File-private registry of per-column [ReorderAnimationScope] keys.
/// Populated by [_CardListViewState] on mount, cleared on dispose.
/// Used by [_executeDrop] to snapshot positions before same-column reorder.
final _reorderScopeKeys = <String, GlobalKey<ReorderAnimationScopeState>>{};

/// Per-column card list. Watches only [cardListProvider] for its own column
/// (fixes Slice 4c — previously all columns re-watched together).
class _CardListView extends ConsumerStatefulWidget {
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
  ConsumerState<_CardListView> createState() => _CardListViewState();
}

class _CardListViewState extends ConsumerState<_CardListView> {
  final _scopeKey = GlobalKey<ReorderAnimationScopeState>();

  @override
  void initState() {
    super.initState();
    _reorderScopeKeys[widget.column.id] = _scopeKey;
  }

  @override
  void dispose() {
    _reorderScopeKeys.remove(widget.column.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardListProvider(widget.column.id));

    void onRetry() => ref.invalidate(cardListProvider(widget.column.id));

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
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Visual affordance: muted hint so empty columns
              // don't look broken or accidentally blank.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Text(
                  'No cards yet',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              _InsertionGap(
                columnId: widget.column.id,
                index: 0,
              ),
            ],
          );
        }

        return ReorderAnimationScope(
          key: _scopeKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                _InsertionGap(
                  key: ValueKey(
                    'gap-${widget.column.id}-$i',
                  ),
                  columnId: widget.column.id,
                  index: i,
                ),
                ReorderAnimationItem(
                  key: ValueKey(cards[i].id),
                  itemKey: ValueKey(cards[i].id),
                  child: AnimatedListItem(
                    staggerIndex: i,
                    child: _DraggableCardSlot(
                      card: cards[i],
                      index: i,
                      columnId: widget.column.id,
                      columnIndex: widget.columnIndex,
                      boardId: widget.boardId,
                      autoScroll: widget.autoScroll,
                      columnWidth: widget.columnWidth,
                    ),
                  ),
                ),
              ],
              // Final gap after last card — allows dropping at end.
              _InsertionGap(
                key: ValueKey(
                  'gap-${widget.column.id}-${cards.length}',
                ),
                columnId: widget.column.id,
                index: cards.length,
              ),
            ],
          ),
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
              // Capture repository while ref is still valid — the card
              // tile will unmount after deletion, making ref unusable
              // inside the snackbar callback.
              final repository = ref.read(boardRepositoryProvider);

              // Undo-delete: delete optimistically, show undo snackbar.
              try {
                await ref
                    .read(cardListProvider(columnId).notifier)
                    .deleteCard(card.id);
              } on Object {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not delete card — please try again'),
                  ),
                );
                return;
              }
              if (!context.mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              messenger.clearSnackBars();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    "'${truncateForDisplay(card.title)}' deleted",
                  ),
                  action: SnackBarAction(
                    label: 'Undo',
                    textColor: Theme.of(context).colorScheme.primary,
                    onPressed: () async {
                      // Re-insert the snapshot — putCard is an upsert.
                      try {
                        await repository.putCard(card);
                      } on Object {
                        if (!context.mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Could not undo — card may be lost'),
                          ),
                        );
                      }
                    },
                  ),
                ),
              );
            case null:
              break;
          }
        },
        child: SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: columnAccentColor(columnIndex),
                  width: 3,
                ),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
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
