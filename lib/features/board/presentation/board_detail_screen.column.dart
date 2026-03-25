part of 'board_detail_screen.dart';

/// 2D scrollable surface hosting columns horizontally and cards vertically.
/// Owns both [ScrollController]s and the [AutoScrollHandler].
class _BoardScrollView extends ConsumerStatefulWidget {
  const _BoardScrollView({
    required this.boardId,
    required this.columns,
  });

  final String boardId;
  final List<KanbanColumn> columns;

  @override
  ConsumerState<_BoardScrollView> createState() => _BoardScrollViewState();
}

class _BoardScrollViewState extends ConsumerState<_BoardScrollView>
    with SingleTickerProviderStateMixin {
  final _horizontalController = ScrollController();
  final _verticalController = ScrollController();
  late final AutoScrollHandler _autoScroll;

  @override
  void initState() {
    super.initState();
    _autoScroll = AutoScrollHandler(
      horizontalController: _horizontalController,
      verticalController: _verticalController,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _autoScroll.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      minimum: EdgeInsets.only(
        bottom: bottomPadding > 0 ? 0 : 12,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _autoScroll.viewportSize = constraints.biggest;
          _autoScroll.viewportRenderBox =
              context.findRenderObject() as RenderBox?;

          final columnCount = widget.columns.length;
          final clampedWidth = computeColumnWidth(
            viewportWidth: constraints.maxWidth,
            columnCount: columnCount,
            marginPerColumn: _kColumnMarginH * 2,
          );
          final totalContentWidth =
              clampedWidth * columnCount +
                  columnCount * _kColumnMarginH * 2;
          final fitsViewport =
              totalContentWidth <= constraints.maxWidth;

          final columns = [
            for (final column in widget.columns)
              _KanbanColumnDropTarget(
                column: column,
                boardId: widget.boardId,
                autoScroll: _autoScroll,
                columnWidth: clampedWidth,
                minHeight:
                    constraints.maxHeight - _kColumnMarginV * 2,
              ),
          ];

          return SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              controller: _verticalController,
              child: IntrinsicHeight(
                child: fitsViewport
                    ? SizedBox(
                        width: constraints.maxWidth,
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: columns,
                        ),
                      )
                    : Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: columns,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// [DragTarget] wrapping an entire column. Accepts cross-column drops on the
/// column body (below cards or on an empty column) — appends to end.
class _KanbanColumnDropTarget extends ConsumerWidget {
  const _KanbanColumnDropTarget({
    required this.column,
    required this.boardId,
    required this.autoScroll,
    required this.columnWidth,
    required this.minHeight,
  });

  final KanbanColumn column;
  final String boardId;
  final AutoScrollHandler autoScroll;
  final double columnWidth;
  final double minHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardCount = ref.watch(
      cardListProvider(column.id)
          .select((async) => async.value?.length ?? 0),
    );

    final isHoverTarget = ref.watch(
      kanbanDragControllerProvider.select((state) {
        return state.isDragging && state.hoverColumnId == column.id;
      }),
    );

    return DragTarget<KanbanCard>(
      onWillAcceptWithDetails: (details) {
        // Column body is the outermost DragTarget — Flutter's depth-first
        // hit-test means this only fires when the pointer is NOT over any
        // card or gap DragTarget (i.e., empty space below cards or an
        // empty column). Oscillation from gap-animation layout shifts is
        // prevented by the no-op guard in updateHover().
        ref
            .read(kanbanDragControllerProvider.notifier)
            .updateHover(columnId: column.id, index: cardCount);
        return true;
      },
      onAcceptWithDetails: (_) => _executeDrop(ref, column.id),
      // No-op: hover is only overwritten by updateHover() or reset by
      // endDrag(). Clearing here caused oscillation — the column onLeave
      // fires spuriously during gap animations as layout shifts change
      // hit-test results between nested DragTargets.
      onLeave: (_) {},
      builder: (context, accepted, rejected) {
        final baseColor = colorScheme.surfaceContainerLow;
        final highlightColor = Color.lerp(
          baseColor,
          colorScheme.primary,
          0.08,
        )!;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: columnWidth,
          constraints: BoxConstraints(minHeight: minHeight),
          margin: const EdgeInsets.symmetric(
            horizontal: _kColumnMarginH,
            vertical: _kColumnMarginV,
          ),
          decoration: BoxDecoration(
            color: isHoverTarget ? highlightColor : baseColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ColumnHeader(
                column: column,
                cardCount: cardCount,
                boardId: boardId,
              ),
              Flexible(
                child: _CardListView(
                  column: column,
                  boardId: boardId,
                  autoScroll: autoScroll,
                  columnWidth: columnWidth,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ColumnEmptyContent extends StatelessWidget {
  const _ColumnEmptyContent({
    required this.state,
    required this.onRetry,
  });

  final AsyncValue<List<KanbanCard>> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: switch (state) {
          AsyncLoading() => const _ColumnCardsSkeleton(),
          AsyncError() => StatusContent(
              icon: Icons.error_outline,
              iconSize: 36,
              iconColor: Theme.of(context).colorScheme.error,
              message: 'Failed to load',
              textStyle: Theme.of(context).textTheme.bodyMedium,
              action: TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ),
          _ => const StatusContent(
              icon: Icons.note_outlined,
              iconSize: 36,
              message: 'No cards yet',
            ),
        },
      ),
    );
  }
}

class _ColumnCardsSkeleton extends StatelessWidget {
  const _ColumnCardsSkeleton();

  @override
  Widget build(BuildContext context) {
    // Lightweight skeleton matching _SkeletonCard shape for per-column loading.
    return const ShimmerScope(
      child: Column(
        children: [
          _SkeletonCard(),
          _SkeletonCard(),
        ],
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
      await guardMutation(
        context,
        () => ref
            .read(columnListProvider(boardId).notifier)
            .renameColumn(column.id, newName),
        'Failed to rename column',
      );
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
      await guardMutation(
        context,
        () => ref
            .read(columnListProvider(boardId).notifier)
            .deleteColumn(column.id),
        'Failed to delete column',
      );
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
          PopupMenuButton<_ColumnMenuAction>(
            onSelected: (action) async {
              switch (action) {
                case _ColumnMenuAction.rename:
                  await _renameColumn(context, ref);
                case _ColumnMenuAction.delete:
                  if (!context.mounted) return;
                  await _deleteColumn(context, ref);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ColumnMenuAction.rename,
                child: Text('Rename'),
              ),
              PopupMenuItem(
                value: _ColumnMenuAction.delete,
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
