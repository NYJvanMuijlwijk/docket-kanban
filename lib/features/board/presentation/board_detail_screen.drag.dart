part of 'board_detail_screen.dart';

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
      // No-op — hover state managed by updateHover(), not by leave events.
      onLeave: (_) {},
      builder: (context, accepted, rejected) {
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
    final viewportBox = widget.autoScroll.viewportRenderBox;
    if (viewportBox == null || !viewportBox.attached) return;
    widget.autoScroll.pointerPosition = viewportBox.globalToLocal(
      details.globalPosition,
    );
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
        width: _kColumnWidth - _kColumnMarginH * 2,
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
      // No-op — hover state managed by updateHover(), not by leave events.
      onLeave: (_) {},
      builder: (context, accepted, rejected) {
        return _AdaptiveDraggable<KanbanCard>(
          data: widget.card,
          feedback: feedback,
          childWhenDragging: ghost,
          onDragStarted: _onDragStarted,
          onDragUpdate: _onDragUpdate,
          onDragEnd: _onDragEnd,
          onDraggableCanceled: _onDraggableCanceled,
          child: child,
        );
      },
    );
  }
}

/// Detects pointer kind at runtime and selects [LongPressDraggable] for touch
/// or [Draggable] for mouse/stylus. Pure Flutter state — no Riverpod needed.
class _AdaptiveDraggable<T extends Object> extends StatefulWidget {
  const _AdaptiveDraggable({
    required this.data,
    required this.feedback,
    required this.childWhenDragging,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDraggableCanceled,
    required this.child,
    super.key,
  });

  final T data;
  final Widget feedback;
  final Widget childWhenDragging;
  final VoidCallback onDragStarted;
  final void Function(DragUpdateDetails) onDragUpdate;
  final void Function(DraggableDetails) onDragEnd;
  final void Function(Velocity, Offset) onDraggableCanceled;
  final Widget child;

  @override
  State<_AdaptiveDraggable<T>> createState() => _AdaptiveDraggableState<T>();
}

class _AdaptiveDraggableState<T extends Object>
    extends State<_AdaptiveDraggable<T>> {
  PointerDeviceKind? _lastPointerKind;

  @override
  Widget build(BuildContext context) {
    final isTouch =
        _lastPointerKind == null || _lastPointerKind == PointerDeviceKind.touch;

    final draggable = isTouch
        ? LongPressDraggable<T>(
            data: widget.data,
            feedback: widget.feedback,
            childWhenDragging: widget.childWhenDragging,
            onDragStarted: widget.onDragStarted,
            onDragUpdate: widget.onDragUpdate,
            onDragEnd: widget.onDragEnd,
            onDraggableCanceled: widget.onDraggableCanceled,
            child: widget.child,
          )
        : Draggable<T>(
            data: widget.data,
            feedback: widget.feedback,
            childWhenDragging: widget.childWhenDragging,
            onDragStarted: widget.onDragStarted,
            onDragUpdate: widget.onDragUpdate,
            onDragEnd: widget.onDragEnd,
            onDraggableCanceled: widget.onDraggableCanceled,
            child: widget.child,
          );

    return Listener(
      onPointerDown: (event) {
        if (_lastPointerKind != event.kind) {
          setState(() {
            _lastPointerKind = event.kind;
          });
        }
      },
      child: draggable,
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
