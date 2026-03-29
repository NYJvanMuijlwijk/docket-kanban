part of 'board_detail_screen.dart';

/// Shared animated ghost card used by both [_InsertionGap] and the
/// original-position ghost in [_DraggableCardSlot]. Animates height
/// between 0 and [height], clipping the child to prevent overflow.
class _AnimatedGhostCard extends StatelessWidget {
  const _AnimatedGhostCard({
    required this.isActive,
    required this.animate,
    required this.height,
    required this.child,
  });

  static const animDuration = Duration(milliseconds: 200);
  static const fallbackHeight = 52.0;

  /// Whether the ghost should be visible (target height = [height]).
  final bool isActive;

  /// Whether to animate the transition. False = instant (e.g., on drop).
  final bool animate;

  /// Measured card height. Falls back to [fallbackHeight] when null.
  final double? height;

  /// Ghost content — typically `Opacity(0.4, IgnorePointer(child: tile))`.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final targetHeight = isActive ? (height ?? fallbackHeight) : 0.0;
    final duration = animate ? animDuration : Duration.zero;

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeInOut,
      height: targetHeight,
      child: ClipRect(child: child),
    );
  }
}

/// Animated gap between cards. Opens to the dragged card's measured height
/// and renders a ghost preview when the drag controller's hover index
/// matches this slot's index.
///
/// Also acts as a [DragTarget] so the gap "catches" the pointer as it
/// animates open — preventing the layout shift from invalidating the
/// hit-test that caused the gap to open in the first place.
class _InsertionGap extends ConsumerWidget {
  const _InsertionGap({
    required this.columnId,
    required this.index,
    super.key,
  });

  final String columnId;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dragData = ref.watch(
      kanbanDragControllerProvider.select((state) {
        final isActive = state.isDragging &&
            state.hoverColumnId == columnId &&
            state.hoverIndex == index;
        return (
          isActive: isActive,
          isDragging: state.isDragging,
          draggedCard: isActive ? state.draggedCard : null,
          draggedCardHeight: isActive ? state.draggedCardHeight : null,
          sourceColumnIndex: isActive ? state.sourceColumnIndex : null,
        );
      }),
    );

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final animate = !reduceMotion && dragData.isDragging;

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
        return _AnimatedGhostCard(
          isActive: dragData.isActive,
          animate: animate,
          height: dragData.draggedCardHeight,
          child: dragData.isActive && dragData.draggedCard != null
              ? Opacity(
                  opacity: 0.4,
                  child: IgnorePointer(
                    child: _KanbanCardTile(
                      card: dragData.draggedCard!,
                      columnId: columnId,
                      columnIndex: dragData.sourceColumnIndex ?? 0,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

/// A card slot that is both draggable (source) and a drop target (destination).
class _DraggableCardSlot extends ConsumerStatefulWidget {
  const _DraggableCardSlot({
    required this.card,
    required this.index,
    required this.columnId,
    required this.columnIndex,
    required this.boardId,
    required this.autoScroll,
    required this.columnWidth,
  });

  final KanbanCard card;
  final int index;
  final String columnId;
  final int columnIndex;
  final String boardId;
  final AutoScrollHandler autoScroll;
  final double columnWidth;

  @override
  ConsumerState<_DraggableCardSlot> createState() => _DraggableCardSlotState();
}

class _DraggableCardSlotState extends ConsumerState<_DraggableCardSlot> {
  void _onDragStarted() {
    final box = context.findRenderObject()! as RenderBox;
    ref.read(kanbanDragControllerProvider.notifier).startDrag(
      card: widget.card,
      sourceColumnId: widget.columnId,
      sourceColumnIndex: widget.columnIndex,
      originalIndex: widget.index,
      draggedCardHeight: box.size.height,
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
      columnIndex: widget.columnIndex,
    );

    // Ghost: shown at original position only when adjacency-suppressed
    // (no-op) or before hovering a valid target. Disappears once the
    // pointer is over a valid non-no-op slot — the gap shows the ghost
    // there instead. Height animates to avoid jarring layout shifts.
    final ghost = Consumer(
      builder: (context, ref, _) {
        final ghostData = ref.watch(
          kanbanDragControllerProvider.select((state) {
            return (
              showGhost: !state.isDragging || state.hoverIndex == null,
              isDragging: state.isDragging,
              draggedCardHeight: state.draggedCardHeight,
            );
          }),
        );
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        return _AnimatedGhostCard(
          isActive: ghostData.showGhost,
          animate: !reduceMotion && ghostData.isDragging,
          height: ghostData.draggedCardHeight,
          child: Opacity(
            opacity: 0.4,
            child: IgnorePointer(child: child),
          ),
        );
      },
    );

    // Feedback: the widget that follows the pointer.
    // Primary-tinted shadow for depth; slight scale increase.
    final colorScheme = Theme.of(context).colorScheme;
    final feedback = Transform.scale(
      scale: 1.04,
      child: Container(
        width: widget.columnWidth - _kColumnMarginH * 2,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            cardTheme: const CardThemeData(margin: EdgeInsets.zero),
          ),
          child: Material(
            borderRadius: BorderRadius.circular(12),
            color: Colors.transparent,
            child: child,
          ),
        ),
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

  unawaited(HapticFeedback.mediumImpact());
  ref.read(kanbanDragControllerProvider.notifier).endDrag();
}
