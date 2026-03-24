import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board/core/reorder_helpers.dart';
import 'package:kanban_board/features/board/domain/board_repository.dart';
import 'package:kanban_board/features/board/domain/kanban_card.dart';
import 'package:kanban_board/features/board/domain/kanban_column.dart';
import 'package:kanban_board/features/board/presentation/auto_scroll_handler.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:kanban_board/features/board/presentation/providers/card_providers.dart';
import 'package:kanban_board/features/board/presentation/providers/column_providers.dart';
import 'package:kanban_board/features/board/presentation/providers/drag_providers.dart';
import 'package:kanban_board/features/board/presentation/widgets/board_form_sheet.dart';
import 'package:kanban_board/features/board/presentation/widgets/card_form_sheet.dart';
import 'package:kanban_board/features/board/presentation/widgets/column_form_sheet.dart';

class BoardDetailScreen extends ConsumerStatefulWidget {
  const BoardDetailScreen({required this.boardId, super.key});

  final String boardId;

  @override
  ConsumerState<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends ConsumerState<BoardDetailScreen> {
  late final AppLifecycleListener _lifecycleListener;

  /// Cached at initState so _stampLastUsed can run in dispose
  /// without touching ref (which is invalid after deactivation).
  late final BoardRepository _repository;
  bool _hasStamped = false;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(boardRepositoryProvider);
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onLifecycleChange,
    );
  }

  @override
  void didUpdateWidget(BoardDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.boardId != widget.boardId) {
      _stampLastUsed();
      _hasStamped = false;
    }
  }

  @override
  void dispose() {
    _stampLastUsed();
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _onLifecycleChange(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _stampLastUsed();
    } else if (state == AppLifecycleState.resumed) {
      // User returned to the app — allow a fresh stamp on next
      // pause/dispose so lastUsedAt reflects the final exit, not
      // the first background event.
      _hasStamped = false;
    }
  }

  /// Stamps `lastUsedAt` on the board. Fire-and-forget — Hive's
  /// in-memory-first writes make the data immediately available.
  /// Guarded by [_hasStamped] to prevent double-writes when
  /// lifecycle callback and dispose race.
  void _stampLastUsed() {
    if (_hasStamped) return;
    _hasStamped = true;

    // Best-effort: repository may already be disposed during teardown.
    unawaited(
      _repository
          .getBoard(widget.boardId)
          .then((board) async {
            if (board != null) {
              await _repository.updateBoard(
                board.copyWith(lastUsedAt: DateTime.now()),
              );
            }
          })
          .catchError(
            // Swallow disposal-related Errors (StateError, HiveError);
            // let Exceptions propagate.
            (_) {},
            test: (e) => e is Error,
          ),
    );
  }

  Future<void> _renameBoard(String currentName) async {
    final newName = await BoardFormSheet.show(
      context,
      initialName: currentName,
    );
    if (newName != null && newName != currentName && mounted) {
      await ref
          .read(boardListProvider.notifier)
          .renameBoard(widget.boardId, newName);
    }
  }

  Future<void> _addColumn() async {
    final name = await ColumnFormSheet.show(context);
    if (name != null && mounted) {
      await ref
          .read(columnListProvider(widget.boardId).notifier)
          .createColumn(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boardAsync = ref.watch(boardProvider(widget.boardId));

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

        final columnsAsync = ref.watch(columnListProvider(widget.boardId));

        return Scaffold(
          appBar: AppBar(
            title: Text(board.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'rename') {
                    await _renameBoard(board.name);
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
            onPressed: _addColumn,
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
              return _BoardScrollView(
                boardId: widget.boardId,
                columns: columns,
              );
            },
          ),
        );
      },
    );
  }
}

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

          return SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              controller: _verticalController,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final column in widget.columns)
                      _KanbanColumnDropTarget(
                        column: column,
                        boardId: widget.boardId,
                        autoScroll: _autoScroll,
                        // Minimum column height = viewport height so columns
                        // fill the screen even with few cards.
                        minHeight: constraints.maxHeight,
                      ),
                  ],
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
    required this.minHeight,
  });

  final KanbanColumn column;
  final String boardId;
  final AutoScrollHandler autoScroll;
  final double minHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardsAsync = ref.watch(cardListProvider(column.id));
    final cardCount = cardsAsync.value?.length ?? 0;

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
      // No clearHover — hover is only overwritten by updateHover() or
      // reset by endDrag(). Clearing here caused oscillation: the column
      // onLeave fires spuriously during gap animations as layout shifts
      // change hit-test results between nested DragTargets.
      onLeave: (_) {},
      builder: (context, candidateData, rejectedData) {
        final baseColor = colorScheme.surfaceContainerLow;
        final highlightColor = Color.lerp(
          baseColor,
          colorScheme.primary,
          0.08,
        )!;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 300,
          constraints: BoxConstraints(minHeight: minHeight),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

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
              _AddCardFooter(columnId: column.id),
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
            _AddCardFooter(columnId: column.id),
          ],
        );
      },
    );
  }
}

/// Animated gap between cards. Opens when the drag controller's hover index
/// matches this slot's index.
///
/// Also acts as a [DragTarget] so the gap "catches" the pointer as it
/// animates open — preventing the layout shift from invalidating the
/// hit-test that caused the gap to open in the first place.
class _InsertionGap extends ConsumerWidget {
  const _InsertionGap({
    required this.columnId,
    required this.index,
  });

  final String columnId;
  final int index;

  static const _gapHeight = 52.0;
  static const _animDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(
      kanbanDragControllerProvider.select((state) {
        return state.isDragging &&
            state.hoverColumnId == columnId &&
            state.hoverIndex == index;
      }),
    );

    return DragTarget<KanbanCard>(
      onWillAcceptWithDetails: (details) {
        ref
            .read(kanbanDragControllerProvider.notifier)
            .updateHover(columnId: columnId, index: index);
        return true;
      },
      onAcceptWithDetails: (_) => _executeDrop(ref, columnId),
      onLeave: (_) {},
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: _animDuration,
          curve: Curves.easeInOut,
          height: isActive ? _gapHeight : 0,
          child: AnimatedOpacity(
            duration: _animDuration,
            curve: Curves.easeInOut,
            opacity: isActive ? 1.0 : 0.0,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _InsertionLine(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Accent-colored horizontal line with rounded pill ends.
class _InsertionLine extends StatelessWidget {
  const _InsertionLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

/// A card slot that is both draggable (source) and a drop target (destination).
///
/// Detects pointer kind at runtime: [LongPressDraggable] for touch,
/// [Draggable] for mouse/stylus.
class _DraggableCardSlot extends ConsumerStatefulWidget {
  const _DraggableCardSlot({
    required this.card,
    required this.index,
    required this.columnId,
    required this.boardId,
    required this.autoScroll,
  });

  final KanbanCard card;
  final int index;
  final String columnId;
  final String boardId;
  final AutoScrollHandler autoScroll;

  @override
  ConsumerState<_DraggableCardSlot> createState() => _DraggableCardSlotState();
}

class _DraggableCardSlotState extends ConsumerState<_DraggableCardSlot> {
  PointerDeviceKind? _lastPointerKind;

  void _onPointerDown(PointerDownEvent event) {
    _lastPointerKind = event.kind;
  }

  void _onDragStarted() {
    ref
        .read(kanbanDragControllerProvider.notifier)
        .startDrag(
          card: widget.card,
          sourceColumnId: widget.columnId,
          originalIndex: widget.index,
        );
    widget.autoScroll.startAutoScroll();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    // Convert global position to viewport-local for auto-scroll.
    final renderBox = context.findAncestorRenderObjectOfType<RenderBox>();
    if (renderBox == null) return;

    // Walk up to the _BoardScrollView's RenderBox for viewport-local coords.
    final scrollViewBox = _findAncestorRenderBox(
      context,
      '_BoardScrollViewState',
    );
    final localPos = (scrollViewBox ?? renderBox).globalToLocal(
      details.globalPosition,
    );

    widget.autoScroll.pointerPosition = localPos;
    ref
        .read(kanbanDragControllerProvider.notifier)
        .updatePosition(details.globalPosition);
  }

  void _onDragEnd(DraggableDetails details) {
    widget.autoScroll.stopAutoScroll();
    // endDrag is called by the accepting DragTarget, not here,
    // so state is still available for the onAccept callback.
  }

  void _onDraggableCanceled(Velocity velocity, Offset offset) {
    widget.autoScroll.stopAutoScroll();
    ref.read(kanbanDragControllerProvider.notifier).endDrag();
  }

  void _handleDrop(DragTargetDetails<KanbanCard> details) {
    _executeDrop(ref, widget.columnId);
  }

  Widget _buildDraggable({
    required Widget child,
    required Widget ghost,
    required Widget feedback,
  }) {
    final isTouch =
        _lastPointerKind == null || _lastPointerKind == PointerDeviceKind.touch;

    if (isTouch) {
      return LongPressDraggable<KanbanCard>(
        data: widget.card,
        feedback: feedback,
        childWhenDragging: ghost,
        onDragStarted: _onDragStarted,
        onDragUpdate: _onDragUpdate,
        onDragEnd: _onDragEnd,
        onDraggableCanceled: _onDraggableCanceled,
        child: child,
      );
    }

    return Draggable<KanbanCard>(
      data: widget.card,
      feedback: feedback,
      childWhenDragging: ghost,
      onDragStarted: _onDragStarted,
      onDragUpdate: _onDragUpdate,
      onDragEnd: _onDragEnd,
      onDraggableCanceled: _onDraggableCanceled,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = _KanbanCardTile(
      card: widget.card,
      columnId: widget.columnId,
    );

    // Ghost: the card left behind at the original position during drag.
    final ghost = Opacity(
      opacity: 0.4,
      child: IgnorePointer(child: child),
    );

    // Feedback: the widget that follows the pointer.
    final feedback = Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 300 - 12, // Column width minus margins
        child: Transform.scale(scale: 1.05, child: child),
      ),
    );

    return DragTarget<KanbanCard>(
      onWillAcceptWithDetails: (details) {
        ref
            .read(kanbanDragControllerProvider.notifier)
            .updateHover(columnId: widget.columnId, index: widget.index);
        return true;
      },
      onAcceptWithDetails: _handleDrop,
      onLeave: (_) {},
      builder: (context, candidateData, rejectedData) {
        return Listener(
          onPointerDown: _onPointerDown,
          child: _buildDraggable(
            child: child,
            ghost: ghost,
            feedback: feedback,
          ),
        );
      },
    );
  }
}

/// Shared drop handler used by all three DragTarget layers (column, card, gap).
///
/// Reads the current [KanbanDragState], computes the new order key based on
/// the hover position, persists the move, and resets drag state.
void _executeDrop(WidgetRef ref, String targetColumnId) {
  final dragState = ref.read(kanbanDragControllerProvider);
  final draggedCard = dragState.draggedCard;
  if (draggedCard == null) return;

  final hoverIndex = dragState.hoverIndex;
  if (hoverIndex == null) {
    // Adjacency-suppressed — no-op.
    ref.read(kanbanDragControllerProvider.notifier).endDrag();
    return;
  }

  if (dragState.sourceColumnId == targetColumnId) {
    // Same-column reorder: convert pre-removal to post-removal index.
    final originalIndex = dragState.originalIndex!;
    final postRemovalIndex = hoverIndex > originalIndex
        ? hoverIndex - 1
        : hoverIndex;
    unawaited(
      ref
          .read(cardListProvider(targetColumnId).notifier)
          .reorderCard(originalIndex, postRemovalIndex),
    );
  } else {
    // Cross-column move: insert at hover position.
    final targetCards = ref.read(cardListProvider(targetColumnId)).value ?? [];
    final targetOrders = targetCards.map((c) => c.order).toList();
    final newOrder = computeOrderKeyAtInsert(targetOrders, hoverIndex);

    unawaited(
      ref
          .read(boardRepositoryProvider)
          .updateCard(
            draggedCard.copyWith(
              columnId: targetColumnId,
              order: newOrder,
              updatedAt: DateTime.now(),
            ),
          ),
    );
  }

  ref.read(kanbanDragControllerProvider.notifier).endDrag();
}

/// Walk up the element tree to find a [RenderBox] whose state matches
/// [stateTypeName]. Used to get the viewport-local coordinates for
/// auto-scroll calculations.
RenderBox? _findAncestorRenderBox(BuildContext context, String stateTypeName) {
  RenderBox? result;
  context.visitAncestorElements((element) {
    if (element is StatefulElement &&
        element.state.runtimeType.toString() == stateTypeName) {
      final renderObject = element.renderObject;
      if (renderObject is RenderBox) {
        result = renderObject;
        return false;
      }
    }
    return true;
  });
  return result;
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
